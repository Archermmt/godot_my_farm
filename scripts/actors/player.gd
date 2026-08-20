class_name FarmPlayer
extends CharacterBody2D

const DIRECTIONS := [&"down", &"left", &"right", &"up"]
const MOTION_STATES := [&"idle", &"walk", &"run"]
const CHARGE_COLOR_LOW := Color("f6e58d")
const CHARGE_COLOR_HIGH := Color("2e7d32")

@export_range(1.0, 500.0, 1.0) var run_speed: float = 96.0
@export_range(1.0, 500.0, 1.0) var walk_speed: float = 48.0
@export_group("Pickup")
@export_range(1.0, 160.0, 1.0) var pickup_radius: float = 72.0
@export_range(1.0, 64.0, 1.0) var pickup_collect_distance: float = 10.0
@export_range(1.0, 600.0, 1.0) var pickup_attraction_speed: float = 180.0
@export_group("Camera")
@export_range(0.0, 2.0, 0.05) var camera_zoom_duration: float = 0.3
@export_group("")

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
@onready var effect_area: EffectArea = $EffectArea
@onready var backpack: PlayerBackpack = get_node_or_null("Backpack") as PlayerBackpack
@onready var charge_bar: ProgressBar = $ChargeBar

var _charge_fill_style: StyleBoxFlat = null


func _ready() -> void:
	assert(walk_speed < run_speed, "walk_speed must be lower than run_speed")
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


func _on_house_interior_changed(_house: Node2D, actor: Node2D, active: bool) -> void:
	if actor != null and actor != self:
		return
	if _camera_zoom_tween != null and _camera_zoom_tween.is_valid():
		_camera_zoom_tween.kill()
	var indoor_zoom := Vector2(1.5, 1.5)
	if is_instance_valid(GameManager) and GameManager.config != null:
		indoor_zoom = GameManager.config.indoor_camera_zoom
	var target_zoom := indoor_zoom if active else _outdoor_camera_zoom
	if camera_zoom_duration <= 0.0:
		camera.zoom = target_zoom
	else:
		_camera_zoom_tween = create_tween()
		_camera_zoom_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_camera_zoom_tween.tween_property(camera, "zoom", target_zoom, camera_zoom_duration)
	EventBus.player_interior_changed.emit(active)


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
		GameManager.skip_day()
	elif event.is_action_pressed("drop") or event.is_action_pressed("drop_held"):
		_drop_held_item()
	elif event.is_action_pressed("cancel"):
		_cancel_interaction()
	elif event.is_action_pressed("toolbar_previous"):
		select_bar_relative(PlayerState.ActiveHandSource.TOOLBAR, -1)
	elif event.is_action_pressed("toolbar_next"):
		select_bar_relative(PlayerState.ActiveHandSource.TOOLBAR, 1)
	elif event.is_action_pressed("itembar_previous"):
		select_bar_relative(PlayerState.ActiveHandSource.ITEMBAR, -1)
	elif event.is_action_pressed("itembar_next"):
		select_bar_relative(PlayerState.ActiveHandSource.ITEMBAR, 1)
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _interact_with_facing_target() -> void:
	if is_input_locked() or (effect_area != null and effect_area.is_charging()):
		return
	var map := MapManager.current_map()
	if map == null:
		return
	var facing_offset: Vector2i = EffectArea.FACING_VECTORS.get(facing, Vector2i.DOWN)
	var target_cell := map.world_to_cell(global_position) + facing_offset
	var target := MapManager.interaction_target_at(target_cell)
	if target == null:
		return
	var rejection: StringName = target.interaction_rejection_reason(state)
	if rejection != &"":
		EventBus.request_invalid_feedback.emit(rejection)
		return
	var result = target.interact(self)
	if result == null:
		return
	var controller: Node = get_tree().get_first_node_in_group("dialogue_controller")
	if controller == null:
		return
	match result.kind:
		1:
			controller.begin(result.dialogue_id, target, self)
		2:
			controller.begin_sleep(target, self)


func _process(delta: float) -> void:
	if effect_area == null:
		return
	if effect_area.is_charging() and is_input_locked():
		_cancel_interaction()
		return
	effect_area.update(delta)
	_refresh_charge_bar()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_interaction()


func _physics_process(delta: float) -> void:
	# EffectArea is top-level so its cell preview uses world coordinates; keep
	# its proximity sensor centered on the player as the player moves.
	if effect_area != null:
		effect_area.global_position = global_position
	input_direction = movement_vector()
	walking = wants_walk()
	if effect_area != null and effect_area.is_charging():
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
	for item: Item in map.pickup_items_in_radius(global_position, pickup_radius):
		_process_pickup(item, map, delta)


func _process_pickup(item: Item, map: BaseMap, delta: float) -> bool:
	if item == null or map == null or state == null or item.meta == null or not item.meta.can_pickup:
		return false
	var offset := global_position - item.global_position
	var distance := offset.length()
	if distance > pickup_collect_distance and distance > 0.0:
		var speed_scale := 1.0 + clampf(1.0 - distance / pickup_radius, 0.0, 1.0) * 2.0
		var travel := pickup_attraction_speed * speed_scale * maxf(delta, 0.0)
		item.global_position += offset / distance * minf(distance, travel)
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
	AudioManager.play_event(&"footstep")


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
	return walk_speed if is_walking else run_speed


func set_facing(value: StringName) -> void:
	if value not in DIRECTIONS:
		return
	set_motion(motion_state, value)
	if effect_area != null and effect_area.is_charging():
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


func animation_name() -> StringName:
	return animation_name_for(motion_state, facing)


func _play_animation() -> void:
	if animation_player == null:
		return
	var next_animation: StringName = animation_name()
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


func clear_input_locks() -> void:
	_lock_reasons.clear()


func set_camera_limits(world_rect: Rect2i) -> Error:
	if world_rect.size.x <= 0 or world_rect.size.y <= 0:
		return ERR_INVALID_PARAMETER
	camera.limit_left = world_rect.position.x
	camera.limit_top = world_rect.position.y
	camera.limit_right = world_rect.end.x
	camera.limit_bottom = world_rect.end.y
	return OK


func debug_snapshot() -> Dictionary:
	var active_stack: BackpackSlot = state.active_stack() if state != null else null
	return {
		"position": global_position,
		"velocity": velocity,
		"input_direction": input_direction,
		"facing": facing,
		"motion_state": motion_state,
		"walking": walking,
		"input_locked": is_input_locked(),
		"animation": animation_name(),
		"animation_player_playing": animation_player.is_playing(),
		"camera_enabled": camera.enabled,
		"active_hand_source": int(state.active_hand_source) if state != null else int(PlayerState.ActiveHandSource.NONE),
		"active_item_id": active_stack.item_id if active_stack != null and not active_stack.is_empty() else &"",
		"selection_popup_visible": selection_popup.visible,
	}


func _on_bar_selection_changed(source: int, _selected_index: int) -> void:
	_show_selection_popup(source as PlayerState.ActiveHandSource)
	AudioManager.play_event(&"ui_confirm")


func _show_selection_popup(source: PlayerState.ActiveHandSource) -> void:
	if state == null:
		return
	var container_id: StringName = &"toolbar" if source == PlayerState.ActiveHandSource.TOOLBAR else &"itembar" if source == PlayerState.ActiveHandSource.ITEMBAR else &""
	if state.backpack_state == null or container_id == &"":
		return
	var capacity := state.backpack_state.capacity(container_id)
	var selected_index := state.backpack_state.selected_toolbar_index if source == PlayerState.ActiveHandSource.TOOLBAR else state.backpack_state.selected_itembar_index
	for child: Node in selection_slots.get_children():
		child.free()
	for index: int in capacity:
		var stack := state.backpack_state.get_slot(container_id, index)
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(24, 24)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if stack != null and not stack.is_empty():
			var meta: ItemMeta = DataCatalog.get_item(stack.item_id)
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
				slot.add_child(icon)
		selection_slots.add_child(slot)
	selection_popup.visible = true
	selection_timer.start()


func _hide_selection_popup() -> void:
	selection_popup.visible = false


func bind_state(next_state: PlayerState) -> Error:
	if next_state == null:
		return ERR_INVALID_PARAMETER
	state = next_state
	facing = state.facing
	if backpack != null:
		backpack.sync_from_player_state(state)
	return OK


func active_stack() -> BackpackSlot:
	return state.active_stack() if state != null else null


func collect_item(item_meta: ItemMeta, amount: int) -> int:
	if state == null or state.backpack_state == null or item_meta == null or item_meta.is_tool() or amount <= 0 or not state.backpack_state.accepts(&"itembar", item_meta):
		return 0
	if state.backpack_state == null:
		return 0
	if backpack != null:
		backpack.sync_from_player_state(state)
	var accepted_by_itembar := state.backpack_state.add_item_partial(&"itembar", item_meta.id, amount, item_meta.stack_limit)
	var remaining := amount - accepted_by_itembar
	var accepted_by_inventory := state.backpack_state.add_item_partial(&"inventory", item_meta.id, remaining, item_meta.stack_limit) if remaining > 0 else 0
	if accepted_by_itembar > 0:
		EventBus.container_changed.emit(&"itembar")
	if accepted_by_inventory > 0:
		EventBus.container_changed.emit(&"inventory")
	if accepted_by_itembar > 0 and state.active_hand_source == PlayerState.ActiveHandSource.ITEMBAR:
		var active := state.active_stack()
		EventBus.active_hand_changed.emit(int(state.active_hand_source), active.item_id, active.amount)
	var accepted := accepted_by_itembar + accepted_by_inventory
	if accepted > 0:
		AudioManager.play_event(&"pickup")
	return accepted


func select_bar_relative(source: PlayerState.ActiveHandSource, offset: int) -> Error:
	_cancel_interaction()
	if state == null:
		return ERR_UNCONFIGURED
	var error := state.select_bar_relative(source, offset)
	if error == OK:
		_emit_selection_changed()
	return error


func select_bar_index(source: PlayerState.ActiveHandSource, index: int) -> Error:
	_cancel_interaction()
	if state == null:
		return ERR_UNCONFIGURED
	var error := state.select_bar_index(source, index)
	if error == OK:
		_emit_selection_changed()
	return error


func exchange_container_slots(source_id: StringName, source_index: int, target_id: StringName, target_index: int) -> Error:
	if state == null:
		return ERR_UNCONFIGURED
	if state.backpack_state == null:
		return ERR_INVALID_PARAMETER
	var source_stack := state.backpack_state.get_slot(source_id, source_index)
	var target_stack := state.backpack_state.get_slot(target_id, target_index)
	var source_meta: ItemMeta = DataCatalog.get_item(source_stack.item_id) if source_stack != null and not source_stack.is_empty() else null
	var target_meta: ItemMeta = DataCatalog.get_item(target_stack.item_id) if target_stack != null and not target_stack.is_empty() else null
	var error := state.exchange_container_slots(source_id, source_index, target_id, target_index, source_meta, target_meta)
	if error == OK:
		EventBus.container_changed.emit(source_id)
		if source_id != target_id:
			EventBus.container_changed.emit(target_id)
		EventBus.active_hand_changed.emit(int(state.active_hand_source), active_stack().item_id if active_stack() != null and not active_stack().is_empty() else &"", active_stack().amount if active_stack() != null and not active_stack().is_empty() else 0)
	return error


func _emit_selection_changed() -> void:
	var selected_index := state.backpack_state.selected_toolbar_index if state.active_hand_source == PlayerState.ActiveHandSource.TOOLBAR else state.backpack_state.selected_itembar_index
	EventBus.bar_selection_changed.emit(int(state.active_hand_source), selected_index)
	var stack := state.active_stack()
	EventBus.active_hand_changed.emit(int(state.active_hand_source), stack.item_id if stack != null and not stack.is_empty() else &"", stack.amount if stack != null and not stack.is_empty() else 0)


func _on_player_state_changed(next_state: PlayerState) -> void:
	_cancel_interaction()
	bind_state(next_state)


func _begin_interaction() -> void:
	if effect_area == null or state == null:
		return
	var stack := state.active_stack()
	if stack == null or stack.is_empty():
		return
	var map: BaseMap = MapManager.current_map()
	if map == null or backpack == null:
		return
	if backpack != null:
		backpack.sync_from_player_state(state)
	var item := backpack.active_item(state)
	if item == null:
		return
	var player_cell := map.world_to_cell(global_position)
	state.cell = player_cell
	if effect_area.begin(state, map, item) == OK:
		_refresh_charge_bar()


func _sync_state_cell() -> void:
	if state == null:
		return
	var map: BaseMap = MapManager.current_map()
	if map == null:
		return
	var current_cell := map.world_to_cell(global_position)
	if not map.contains_cell(current_cell):
		return
	if effect_area != null and effect_area.is_charging():
		effect_area.move_origin(current_cell)
	else:
		state.cell = current_cell


func _release_interaction() -> void:
	if effect_area == null or state == null or backpack == null:
		return
	var map: BaseMap = MapManager.current_map()
	var item := backpack.active_item(state)
	if map == null or item == null:
		_cancel_interaction()
		_emit_invalid_interaction()
		return
	var target_cells := effect_area.preview_cells(false)
	var valid_cells := effect_area.preview_cells(true)
	var charge_level := effect_area.charge_level
	var release_error := effect_area.release_preview()
	_hide_charge_bar()
	if release_error != OK:
		_emit_invalid_interaction()
		return
	if item is Tool:
		var tool_result := (item as Tool).use(map, target_cells, state.stamina, state.cell, charge_level)
		if tool_result.error != OK:
			_emit_invalid_interaction()
			return
		var stamina_spent := tool_result.stamina_spent
		if stamina_spent > 0 and state.consume_energy(stamina_spent):
			if state.stamina <= 0:
				GameManager.request_end_day()
			EventBus.player_state_changed.emit(state)
		_emit_tool_outcome(tool_result)
	elif item is Seed:
		var stack := state.active_stack()
		var available_count := stack.amount if stack != null and not stack.is_empty() else 0
		var seed_outcome := (item as Seed).use(map, valid_cells, GameManager.calendar.day, available_count)
		if seed_outcome.error != OK:
			_emit_invalid_interaction()
			return
		if seed_outcome.consumed_count() > 0:
			backpack.remove_item(&"itembar", seed_outcome.seed_item_id, seed_outcome.consumed_count())
			EventBus.container_changed.emit(&"itembar")
			backpack.sync_from_player_state(state)
			var active := state.active_stack()
			EventBus.active_hand_changed.emit(
				int(state.active_hand_source),
				active.item_id if active != null and not active.is_empty() else &"",
				active.amount if active != null and not active.is_empty() else 0
			)
	else:
		_emit_invalid_interaction()


func _drop_held_item() -> void:
	if state == null or state.active_hand_source == PlayerState.ActiveHandSource.NONE:
		return
	var stack := state.active_stack()
	var map: BaseMap = MapManager.current_map()
	var item_meta := DataCatalog.get_item(stack.item_id) if stack != null and not stack.is_empty() else null
	if stack == null or stack.is_empty() or item_meta == null or not item_meta.dropable or map == null:
		return
	var facing_offset: Vector2i = EffectArea.FACING_VECTORS.get(state.facing, Vector2i.DOWN)
	var target_cell: Vector2i = map.world_to_cell(global_position) + facing_offset
	if effect_area != null and effect_area.is_charging():
		var preview_cells := effect_area.preview_cells(true)
		if not preview_cells.is_empty():
			target_cell = preview_cells[0]
	if not map.check_cell(target_cell, BaseMap.CellCondition.DROPABLE):
		return
	var dropped_item_id := stack.item_id
	if map.spawn_pickup(dropped_item_id, target_cell) == &"":
		return
	var container_id: StringName = &"toolbar" if state.active_hand_source == PlayerState.ActiveHandSource.TOOLBAR else &"itembar"
	if not backpack.remove_item(container_id, dropped_item_id, 1):
		return
	EventBus.container_changed.emit(container_id)
	if backpack != null:
		backpack.sync_from_player_state(state)
	var active := state.active_stack()
	EventBus.active_hand_changed.emit(int(state.active_hand_source), active.item_id if active != null and not active.is_empty() else &"", active.amount if active != null and not active.is_empty() else 0)


func _emit_invalid_interaction() -> void:
	EventBus.request_invalid_feedback.emit(&"invalid_target")
	AudioManager.play_event(&"invalid")


func _emit_tool_outcome(result: ToolOutcome) -> void:
	if result == null:
		return
	EventBus.cells_tool_used.emit(result.tool_kind, result.effect_cells, result.stamina_spent)
	if result is CellToolOutcome:
		var cell_result := result as CellToolOutcome
		if cell_result.projection_error != OK:
			EventBus.cell_projection_failed.emit(cell_result.effect_cells, cell_result.projection_error)
	var event_id: StringName
	match result.tool_kind:
		ToolMeta.ToolKind.HOE:
			event_id = &"till"
		ToolMeta.ToolKind.WATERING_CAN:
			event_id = &"water"
		ToolMeta.ToolKind.SICKLE:
			event_id = &"cut"
		ToolMeta.ToolKind.BASKET:
			event_id = &"harvest"
		ToolMeta.ToolKind.PICKAXE:
			event_id = &"mine"
		ToolMeta.ToolKind.AXE:
			event_id = &"chop"
		_:
			event_id = &"tool_use"
	EventBus.request_tool_feedback.emit(event_id, result.effect_cells)
	AudioManager.play_event(event_id)


func _cancel_interaction() -> void:
	if effect_area != null:
		effect_area.cancel()
	_hide_charge_bar()


func _refresh_charge_bar() -> void:
	if charge_bar == null or effect_area == null or not effect_area.is_charging():
		_hide_charge_bar()
		return
	charge_bar.visible = true
	var progress := effect_area.charge_progress()
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
