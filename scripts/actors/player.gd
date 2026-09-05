class_name FarmPlayer
extends CharacterBody2D

const DIRECTIONS := [&"down", &"left", &"right", &"up"]
const MOTION_STATES := [&"idle", &"walk", &"run"]
const CHARGE_COLOR_LOW := Color("f6e58d")
const CHARGE_COLOR_HIGH := Color("2e7d32")

var run_speed: float:
	get:
		return state.run_speed if state != null else 0.0
var walk_speed: float:
	get:
		return state.walk_speed if state != null else 0.0
var pickup_radius: float:
	get:
		return state.pickup_radius if state != null else 0.0
var pickup_collect_distance: float:
	get:
		return state.pickup_collect_distance if state != null else 0.0
var trace_delay: Dictionary[StringName, float]:
	get:
		return state.trace_delay if state != null else {}
var pickup_speed_curve: Curve:
	get:
		return state.pickup_speed_curve if state != null else null
var indoor_camera_zoom: Vector2:
	get:
		return state.indoor_camera_zoom if state != null else Vector2.ONE
var camera_zoom_duration: float:
	get:
		return state.camera_zoom_duration if state != null else 0.0
	set(value):
		if state != null:
			state.camera_zoom_duration = value

var input_direction: Vector2 = Vector2.ZERO
var facing: StringName = &"down"
var motion_state: StringName = &"idle"
var walking: bool = false
var state: PlayerState = null

var _lock_reasons: Dictionary[StringName, bool] = {}
var _footstep_elapsed: float = 0.0
var _camera_zoom_tween: Tween = null
var _outdoor_camera_zoom := Vector2.ONE

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var camera: Camera2D = $Camera2D
@onready var selection_popup: Control = $SelectionPopup
@onready var selection_slots: HBoxContainer = $SelectionPopup/Slots
@onready var selection_timer: Timer = $SelectionTimer
@onready var interact_area: InteractArea = $InteractArea
@onready var backpack: PlayerBackpack = get_node_or_null("Backpack") as PlayerBackpack
@onready var charge_bar: ProgressBar = $ChargeBar

var _charge_fill_style: StyleBoxFlat = null


func _ready() -> void:
	_play_animation()
	_outdoor_camera_zoom = camera.zoom
	selection_timer.timeout.connect(_hide_selection_popup)
	_charge_fill_style = charge_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	charge_bar.add_theme_stylebox_override("fill", _charge_fill_style)
	charge_bar.visible = false
	if not EventBus.bar_selection_changed.is_connected(_on_bar_selection_changed):
		EventBus.bar_selection_changed.connect(_on_bar_selection_changed)
	if not EventBus.player_state_changed.is_connected(_on_player_state_changed):
		EventBus.player_state_changed.connect(_on_player_state_changed)
	if not EventBus.house_interior_changed.is_connected(_on_house_interior_changed):
		EventBus.house_interior_changed.connect(_on_house_interior_changed)
	if not EventBus.map_changed.is_connected(_on_map_changed):
		EventBus.map_changed.connect(_on_map_changed)


func _on_map_changed(_map_id: StringName) -> void:
	var map := MapManager.current_map()
	if map == null:
		return
	var spawn := map.spawn_position(MapManager.current_spawn_id())
	global_position = spawn
	if state != null:
		state.position = spawn
	var world_bounds := Rect2(Vector2.ZERO, Vector2(map.get_map_size() * map.get_tile_size()))
	set_camera_limits(Rect2i(world_bounds.position, world_bounds.size))


func _unhandled_input(event: InputEvent) -> void:
	if state == null:
		return
	if event.is_action_released("use_held"):
		_release_interaction()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("quick_save"):
		GameManager.save_slot(0)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("quick_load"):
		GameManager.load_slot(0)
		get_viewport().set_input_as_handled()
		return
	if is_input_locked() or not event.is_pressed() or (event is InputEventKey and event.is_echo()):
		return
	var handled := true
	if event.is_action_pressed("use_held"):
		_begin_interaction()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_interact_with_facing_target()
	elif event.is_action_pressed("skip_day"):
		CalendarManager.advance_to_next_day()
	elif event.is_action_pressed("drop") or event.is_action_pressed("drop_held"):
		_drop_held_item()
	elif event.is_action_pressed("cancel"):
		_cancel_interaction()
	elif event.is_action_pressed("toolbar_previous"):
		_cancel_interaction()
		if backpack != null:
			backpack.select_bar_relative(BackpackState.ActiveHandSource.TOOLBAR, -1)
	elif event.is_action_pressed("toolbar_next"):
		_cancel_interaction()
		if backpack != null:
			backpack.select_bar_relative(BackpackState.ActiveHandSource.TOOLBAR, 1)
	elif event.is_action_pressed("itembar_previous"):
		_cancel_interaction()
		if backpack != null:
			backpack.select_bar_relative(BackpackState.ActiveHandSource.ITEMBAR, -1)
	elif event.is_action_pressed("itembar_next"):
		_cancel_interaction()
		if backpack != null:
			backpack.select_bar_relative(BackpackState.ActiveHandSource.ITEMBAR, 1)
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _interact_with_facing_target() -> void:
	if is_input_locked() or (interact_area != null and interact_area.is_charging()):
		return
	InteractManager.interact(self)


func _process(delta: float) -> void:
	if interact_area == null:
		return
	if interact_area.is_charging() and is_input_locked():
		_cancel_interaction()
		return
	interact_area.update(delta)
	_refresh_charge_bar()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_interaction()


func _physics_process(delta: float) -> void:
	# InteractArea is top-level so its cell preview uses world coordinates; keep
	# its proximity sensor centered on the player as the player moves.
	if interact_area != null:
		interact_area.global_position = global_position
	input_direction = movement_vector()
	walking = wants_walk()
	if interact_area != null and interact_area.is_charging():
		# Keep movement continuous while locking facing. The cursor itself only
		# refreshes after _sync_state_cell() observes a crossed cell boundary.
		velocity = velocity_for(input_direction, walking)
		move_and_slide()
		set_motion(resolve_motion_state(input_direction, walking), facing)
		_process_footsteps(delta)
		_sync_state_cell()
		return
	else:
		facing = resolve_facing(input_direction, facing)
	velocity = velocity_for(input_direction, walking)
	move_and_slide()
	set_motion(resolve_motion_state(input_direction, walking), facing)
	_process_footsteps(delta)
	_sync_state_cell()
	_process_pickups(delta)


func _process_pickups(delta: float) -> void:
	var map: BaseMap = MapManager.current_map()
	if map == null:
		return
	for item: Item in ItemManager.get_pickups():
		_process_pickup(item, map, delta)


func _process_pickup(item: Item, map: BaseMap, delta: float) -> bool:
	if item == null or map == null or state == null or item.meta == null or not item.meta.can_pickup:
		return false
	var offset := global_position - item.global_position
	var distance := offset.length()
	# Contact pickup always wins. Distant attraction requires the item's area
	# signal and trace timer to have enabled player tracking.
	if distance > state.pickup_collect_distance and distance > 0.0:
		if not item.is_tracing_player():
			return false
		var proximity := clampf(1.0 - distance / state.pickup_radius, 0.0, 1.0)
		var speed := 0.0
		if state.pickup_speed_curve != null:
			speed = maxf(state.pickup_speed_curve.sample_baked(proximity), 0.0)
		var travel := speed * maxf(delta, 0.0)
		var target_position := item.global_position + offset / distance * minf(distance, travel)
		var move_error := map.move_item(item.item_id(), target_position)
		assert(move_error == OK, "Moving pickup must remain inside the current map")
		return false
	if collect_item(item.meta, 1) != 1:
		return false
	var remove_error := map.remove_item(item.item_id())
	assert(remove_error == OK, "Collected Item must still belong to the current map")
	return remove_error == OK


func _process_footsteps(delta: float) -> void:
	if velocity.is_zero_approx():
		_footstep_elapsed = 0.0
		return
	_footstep_elapsed += maxf(0.0, delta)
	var interval := 0.34 if walking else 0.24
	if _footstep_elapsed < interval:
		return
	_footstep_elapsed = 0.0
	AudioManager.play_audio(&"footstep")


func movement_vector() -> Vector2:
	if is_input_locked():
		return Vector2.ZERO
	var raw := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return normalized_direction(raw)


func wants_walk() -> bool:
	return not is_input_locked() and Input.is_action_pressed("walk_modifier")


func velocity_for(direction: Vector2, is_walking: bool) -> Vector2:
	if direction.is_zero_approx():
		return Vector2.ZERO
	return normalized_direction(direction) * speed_for(is_walking)


func speed_for(is_walking: bool) -> float:
	return state.walk_speed if state != null and is_walking else state.run_speed if state != null else 0.0


func set_facing(value: StringName) -> void:
	if value not in DIRECTIONS:
		return
	set_motion(motion_state, value)
	if interact_area != null and interact_area.is_charging():
		_cancel_interaction()


func set_motion(next_state: StringName, next_facing: StringName) -> void:
	if next_state not in MOTION_STATES:
		next_state = &"idle"
	if next_facing not in DIRECTIONS:
		next_facing = facing
	motion_state = next_state
	facing = next_facing
	if state != null:
		state.facing = facing
	_play_animation()


func _play_animation() -> void:
	if animation_player == null:
		return
	var next_animation: StringName = animation_name_for(motion_state, facing)
	if animation_player.current_animation != next_animation or not animation_player.is_playing():
		animation_player.play(next_animation)


func lock_input(reason: StringName) -> Error:
	if reason == &"":
		return ERR_INVALID_PARAMETER
	_lock_reasons[reason] = true
	return OK


func unlock_input(reason: StringName) -> Error:
	if reason == &"":
		return ERR_INVALID_PARAMETER
	if not _lock_reasons.erase(reason):
		return ERR_DOES_NOT_EXIST
	return OK


func is_input_locked() -> bool:
	return not _lock_reasons.is_empty()


func input_lock_reasons() -> Array[StringName]:
	var reasons: Array[StringName] = []
	reasons.assign(_lock_reasons.keys())
	return reasons


func set_camera_limits(world_rect: Rect2i) -> Error:
	if world_rect.size.x <= 0 or world_rect.size.y <= 0:
		return ERR_INVALID_PARAMETER
	camera.limit_left = world_rect.position.x
	camera.limit_top = world_rect.position.y
	camera.limit_right = world_rect.end.x
	camera.limit_bottom = world_rect.end.y
	return OK


func _show_selection_popup(source: BackpackState.ActiveHandSource) -> void:
	if state == null:
		return
	var container_id: StringName = (
		&"toolbar"
		if source == BackpackState.ActiveHandSource.TOOLBAR
		else &"itembar" if source == BackpackState.ActiveHandSource.ITEMBAR else &""
	)
	if backpack == null or backpack.backpack_state == null or container_id == &"":
		return
	var capacity := backpack.backpack_state.capacity(container_id)
	var selected_index := backpack.selected_index(container_id)
	for child: Node in selection_slots.get_children():
		child.free()
	for index: int in capacity:
		var backpack_slot := backpack.backpack_state.get_slot(container_id, index)
		var slot_control := Control.new()
		slot_control.custom_minimum_size = Vector2(24, 24)
		slot_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if backpack_slot != null and not backpack_slot.is_empty():
			var meta: ItemMeta = DataCatalog.get_item(backpack_slot.item_id)
			if meta != null and meta.icon_texture != null:
				var icon := TextureRect.new()
				icon.name = "Icon"
				icon.set_anchors_preset(Control.PRESET_CENTER)
				icon.position = Vector2(-8, -8)
				icon.size = Vector2(16, 16)
				icon.pivot_offset = icon.size * 0.5
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				icon.texture = meta.icon_texture
				icon.scale = Vector2(1.35, 1.35) if index == selected_index else Vector2.ONE
				icon.tooltip_text = meta.display_name
				slot_control.add_child(icon)
		selection_slots.add_child(slot_control)
	selection_popup.visible = true
	selection_timer.start()


func _hide_selection_popup() -> void:
	selection_popup.visible = false


func _on_house_interior_changed(_house: Node2D, actor: Node2D, active: bool) -> void:
	if actor != null and actor != self:
		return
	if _camera_zoom_tween != null and _camera_zoom_tween.is_valid():
		_camera_zoom_tween.kill()
	var target_zoom := state.indoor_camera_zoom if active and state != null else _outdoor_camera_zoom
	if state == null or state.camera_zoom_duration <= 0.0:
		camera.zoom = target_zoom
	else:
		_camera_zoom_tween = create_tween()
		_camera_zoom_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_camera_zoom_tween.tween_property(camera, "zoom", target_zoom, state.camera_zoom_duration)
	EventBus.player_interior_changed.emit(active)


func _on_bar_selection_changed(source: int, _selected_index: int) -> void:
	_show_selection_popup(source as BackpackState.ActiveHandSource)
	AudioManager.play_audio(&"ui_confirm")


func _on_player_state_changed(next_state: PlayerState) -> void:
	_cancel_interaction()
	setup(next_state)


func setup(next_state: PlayerState) -> Error:
	if next_state == null:
		return ERR_INVALID_PARAMETER
	state = next_state
	facing = state.facing
	return OK


func collect_item(item_meta: ItemMeta, amount: int) -> int:
	if (
		state == null
		or backpack == null
		or backpack.backpack_state == null
		or item_meta == null
		or item_meta is ToolMeta
		or amount <= 0
		or not backpack.accepts(&"itembar", item_meta)
	):
		return 0
	var accepted_by_itembar := backpack.add_item(&"itembar", item_meta.id, amount, item_meta.stack_limit)
	var remaining := amount - accepted_by_itembar
	var accepted_by_inventory := (
		backpack.add_item(&"main_space", item_meta.id, remaining, item_meta.stack_limit) if remaining > 0 else 0
	)
	if accepted_by_itembar > 0:
		EventBus.container_changed.emit(&"itembar")
	if accepted_by_inventory > 0:
		EventBus.container_changed.emit(&"main_space")
	if accepted_by_itembar > 0 and backpack.backpack_state.active_hand_source == BackpackState.ActiveHandSource.ITEMBAR:
		var active := backpack.active_slot()
		EventBus.active_hand_changed.emit(
			int(backpack.backpack_state.active_hand_source), active.item_id, active.amount
		)
	var accepted := accepted_by_itembar + accepted_by_inventory
	if accepted > 0:
		AudioManager.play_audio(&"pickup")
	return accepted


func _begin_interaction() -> void:
	if interact_area == null or state == null:
		return
	var slot := backpack.active_slot() if backpack != null else null
	if slot == null or slot.is_empty():
		return
	var map: BaseMap = MapManager.current_map()
	if map == null or backpack == null:
		return
	var item := backpack.active_item()
	if item == null:
		return
	var player_cell := map.world_to_cell(global_position)
	state.position = global_position
	if interact_area.begin(state, backpack, map, item) == OK:
		_refresh_charge_bar()


func _sync_state_cell() -> void:
	if state == null:
		return
	var map: BaseMap = MapManager.current_map()
	if map == null:
		return
	var current_cell := map.world_to_cell(global_position)
	if not map.cells.has(current_cell):
		return
	if interact_area != null and interact_area.is_charging():
		interact_area.move_origin(current_cell)
	else:
		state.position = global_position


func _release_interaction() -> void:
	if interact_area == null or state == null or backpack == null:
		return
	var map: BaseMap = MapManager.current_map()
	var item := backpack.active_item()
	if map == null or item == null:
		_cancel_interaction()
		_emit_invalid_interaction()
		return
	var target_cells := interact_area.preview_cells(false)
	var valid_cells := interact_area.preview_cells(true)
	var charge_level := interact_area.charge_level
	var release_error := interact_area.release_preview()
	_hide_charge_bar()
	if release_error != OK:
		_emit_invalid_interaction()
		return
	if item is Tool:
		var tool_result := (item as Tool).use(map, target_cells, state.energy, charge_level)
		if not tool_result.succeeded():
			_emit_invalid_interaction()
			return
		var energy_spent := (item.meta as ToolMeta).level_energy_cost(charge_level)
		if energy_spent > 0 and state.consume_energy(energy_spent):
			if state.energy <= 0:
				CalendarManager.advance_to_next_day()
			EventBus.player_state_changed.emit(state)
	elif item is Seed:
		var slot := backpack.active_slot()
		var available_count := slot.amount if slot != null and not slot.is_empty() else 0
		var seed_result := (item as Seed).use(map, valid_cells, available_count)
		if not seed_result.succeeded():
			_emit_invalid_interaction()
			return
		var consumed_count := seed_result.cells.size()
		if consumed_count > 0:
			backpack.remove_item(&"itembar", item.meta.id, consumed_count)
			EventBus.container_changed.emit(&"itembar")
			var active := backpack.active_slot()
			EventBus.active_hand_changed.emit(
				int(backpack.backpack_state.active_hand_source),
				active.item_id if active != null and not active.is_empty() else &"",
				active.amount if active != null and not active.is_empty() else 0
			)
	else:
		_emit_invalid_interaction()


func _drop_held_item() -> void:
	if (
		state == null
		or backpack == null
		or backpack.backpack_state == null
		or backpack.backpack_state.active_hand_source == BackpackState.ActiveHandSource.NONE
	):
		return
	var slot := backpack.active_slot()
	var map: BaseMap = MapManager.current_map()
	var item_meta := DataCatalog.get_item(slot.item_id) if slot != null and not slot.is_empty() else null
	if slot == null or slot.is_empty() or item_meta == null or not item_meta.dropable or map == null:
		return
	var facing_offset: Vector2i = InteractArea.FACING_VECTORS.get(state.facing, Vector2i.DOWN)
	var target_cell: Vector2i = map.world_to_cell(global_position) + facing_offset
	if interact_area != null and interact_area.is_charging():
		var preview_cells := interact_area.preview_cells(true)
		if not preview_cells.is_empty():
			target_cell = preview_cells[0]
	if not map.check_cell(target_cell, CellState.CellCondition.DROPABLE):
		return
	var dropped_item_id := slot.item_id
	var dropped_item := ItemManager.create_from_id(dropped_item_id)
	if dropped_item == null or map.add_item(dropped_item, map.cell_to_world(target_cell)) != OK:
		if dropped_item != null:
			dropped_item.free()
		return
	dropped_item.set_trace_delay(trace_delay_for(&"drop"))
	var container_id: StringName = (
		&"toolbar"
		if backpack.backpack_state.active_hand_source == BackpackState.ActiveHandSource.TOOLBAR
		else &"itembar"
	)
	if not backpack.remove_item(container_id, dropped_item_id, 1):
		return
	EventBus.container_changed.emit(container_id)
	var active := backpack.active_slot()
	EventBus.active_hand_changed.emit(
		int(backpack.backpack_state.active_hand_source),
		active.item_id if active != null and not active.is_empty() else &"",
		active.amount if active != null and not active.is_empty() else 0
	)


func trace_delay_for(source: StringName) -> float:
	return maxf(float(state.trace_delay.get(source, 0.0)), 0.0) if state != null else 0.0


func _emit_invalid_interaction() -> void:
	EventBus.request_invalid_feedback.emit(&"invalid_target")
	AudioManager.play_audio(&"invalid")


func _cancel_interaction() -> void:
	if interact_area != null:
		interact_area.cancel()
	_hide_charge_bar()


func _refresh_charge_bar() -> void:
	if charge_bar == null or interact_area == null or not interact_area.is_charging():
		_hide_charge_bar()
		return
	charge_bar.visible = true
	var progress := interact_area.charge_progress()
	charge_bar.value = progress
	if _charge_fill_style != null:
		_charge_fill_style.bg_color = CHARGE_COLOR_LOW.lerp(CHARGE_COLOR_HIGH, progress)


func _hide_charge_bar() -> void:
	if charge_bar == null:
		return
	charge_bar.visible = false
	charge_bar.value = 0.0


static func normalized_direction(raw: Vector2) -> Vector2:
	if raw.is_zero_approx():
		return Vector2.ZERO
	return raw.normalized()


static func resolve_facing(direction: Vector2, previous: StringName = &"down") -> StringName:
	if not is_zero_approx(direction.x):
		return &"right" if direction.x > 0.0 else &"left"
	if not is_zero_approx(direction.y):
		return &"down" if direction.y > 0.0 else &"up"
	return previous


static func resolve_motion_state(direction: Vector2, is_walking: bool) -> StringName:
	if direction.is_zero_approx():
		return &"idle"
	return &"walk" if is_walking else &"run"


static func animation_name_for(state: StringName, direction: StringName) -> StringName:
	var safe_state: StringName = state if state in MOTION_STATES else &"idle"
	var safe_direction: StringName = direction if direction in DIRECTIONS else &"down"
	return StringName("%s_%s" % [safe_state, safe_direction])
