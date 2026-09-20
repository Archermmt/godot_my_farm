class_name FarmPlayer
extends CharacterBody2D

const DIRECTIONS := [&"down", &"left", &"right", &"up"]
const MOTION_STATES := [&"idle", &"walk", &"run"]
const CHARGE_COLOR_LOW := Color("f6e58d")
const CHARGE_COLOR_HIGH := Color("2e7d32")

var run_speed: float = 0.0
var walk_speed: float = 0.0
var pickup_radius: float = 0.0
var pickup_collect_distance: float = 0.0
var trace_delay: Dictionary[StringName, float] = {}
var pickup_speed_curve: Curve = null
var indoor_camera_zoom: Vector2 = Vector2.ONE
var camera_zoom_duration: float = 0.0
var input_direction: Vector2 = Vector2.ZERO
var facing: StringName = &"down"
var motion_state: StringName = &"idle"
var walking: bool = false
var current_interactable: Node2D = null
var health: int = 100
var max_health: int = 100
var energy: int = 100
var max_energy: int = 100
var gold: int = 500

var _lock_reasons: Dictionary[StringName, bool] = {}
var _footstep_elapsed: float = 0.0
var _camera_zoom_tween: Tween = null
var _outdoor_camera_zoom := Vector2.ONE

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var camera: Camera2D = $Camera2D
@onready var selection_popup: Control = $SelectionPopup
@onready var selection_slots: HBoxContainer = $SelectionPopup/Slots
@onready var selection_timer: Timer = $SelectionTimer
@onready var interact_area: Area2D = $InteractArea
@onready var backpack: PlayerBackpack = get_node_or_null("Backpack") as PlayerBackpack
@onready var charge_bar: ProgressBar = $ChargeBar

var _charge_fill_style: StyleBoxFlat = null


func _ready() -> void:
	var config := DataCatalog.config
	if config != null:
		position = Vector2.ZERO
		facing = config.player_facing
		max_health = config.player_max_health
		health = clampi(config.player_initial_health, 0, max_health)
		max_energy = config.player_max_energy
		energy = clampi(config.player_initial_energy, 0, max_energy)
		gold = maxi(0, config.player_initial_gold)
		run_speed = config.player_run_speed
		walk_speed = config.player_walk_speed
		pickup_radius = config.player_pickup_radius
		pickup_collect_distance = config.player_pickup_collect_distance
		trace_delay = config.player_trace_delay.duplicate(true)
		pickup_speed_curve = config.player_pickup_speed_curve
		indoor_camera_zoom = config.player_indoor_camera_zoom
		camera_zoom_duration = config.player_camera_zoom_duration
	_play_animation()
	_outdoor_camera_zoom = camera.zoom
	selection_timer.timeout.connect(_hide_selection_popup)
	_charge_fill_style = charge_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	charge_bar.add_theme_stylebox_override("fill", _charge_fill_style)
	charge_bar.visible = false
	if not EventBus.bar_selection_changed.is_connected(_on_bar_selection_changed):
		EventBus.bar_selection_changed.connect(_on_bar_selection_changed)
	if not EventBus.house_interior_changed.is_connected(_on_house_interior_changed):
		EventBus.house_interior_changed.connect(_on_house_interior_changed)
	if not interact_area.area_entered.is_connected(_on_interaction_area_entered):
		interact_area.area_entered.connect(_on_interaction_area_entered)
	if not interact_area.area_exited.is_connected(_on_interaction_area_exited):
		interact_area.area_exited.connect(_on_interaction_area_exited)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_save"):
		GameManager.save_game(0)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("quick_load"):
		GameManager.load_game(0)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_released("use_held"):
		_use_tool()
		get_viewport().set_input_as_handled()
		return
	if is_input_locked() or not event.is_pressed() or (event is InputEventKey and event.is_echo()):
		return
	var handled := true
	if event.is_action_pressed("interact"):
		_interact_with_facing_target()
	elif event.is_action_pressed("skip_day"):
		CalendarManager.next_day()
	elif event.is_action_pressed("drop"):
		_drop_item()
	elif event.is_action_pressed("use_held"):
		_begin_hold()
	elif event.is_action_pressed("cancel"):
		_cancel_hold()
	elif event.is_action_pressed("toolbar_previous"):
		_cancel_hold()
		if backpack != null:
			backpack.select_bar_relative(PlayerBackpack.ActiveHandSource.TOOLBAR, -1)
	elif event.is_action_pressed("toolbar_next"):
		_cancel_hold()
		if backpack != null:
			backpack.select_bar_relative(PlayerBackpack.ActiveHandSource.TOOLBAR, 1)
	elif event.is_action_pressed("itembar_previous"):
		_cancel_hold()
		if backpack != null:
			backpack.select_bar_relative(PlayerBackpack.ActiveHandSource.ITEMBAR, -1)
	elif event.is_action_pressed("itembar_next"):
		_cancel_hold()
		if backpack != null:
			backpack.select_bar_relative(PlayerBackpack.ActiveHandSource.ITEMBAR, 1)
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	input_direction = movement_vector()
	walking = not is_input_locked() and Input.is_action_pressed("walk_modifier")
	var active_tool := backpack.active_item() as Tool if backpack != null else null
	if active_tool != null and active_tool.is_charging():
		if is_input_locked():
			_cancel_hold()
		else:
			active_tool.update_charge(delta)
	var is_charging: bool = active_tool != null and active_tool.is_charging()
	if not is_charging:
		facing = resolve_facing(input_direction, facing)
	velocity = velocity_for(input_direction, walking)
	move_and_slide()
	set_motion(input_direction, walking, facing)
	_process_footsteps(delta)
	_process_pickups(delta)
	if is_charging:
		_refresh_charge_bar()


func _interact_with_facing_target() -> void:
	if is_input_locked():
		return
	if (
		current_interactable != null
		and is_instance_valid(current_interactable)
		and current_interactable.has_method("interact")
	):
		current_interactable.interact()


func _process_pickups(delta: float) -> void:
	var map: BaseMap = MapManager.current_map()
	if map == null:
		return
	for item: Item in ItemManager.get_pickups():
		if item.meta == null or not item.meta.can_pickup:
			continue
		if not item.is_tracing_player():
			continue
		var offset := global_position - item.global_position
		var distance := offset.length()
		if distance > pickup_collect_distance:
			var proximity := clampf(1.0 - distance / pickup_radius, 0.0, 1.0)
			var speed := 0.0
			if pickup_speed_curve != null:
				speed = maxf(pickup_speed_curve.sample_baked(proximity), 0.0)
			item.speed = speed
			item.move_toward_position(global_position, maxf(delta, 0.0))
			continue
		if collect_item(item.meta, 1) != 1:
			continue
		map.remove_item(item.item_id())


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


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_hold()


func movement_vector() -> Vector2:
	if is_input_locked():
		return Vector2.ZERO
	var raw := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return normalized_direction(raw)


func velocity_for(direction: Vector2, is_walking: bool) -> Vector2:
	if direction.is_zero_approx():
		return Vector2.ZERO
	return normalized_direction(direction) * (walk_speed if is_walking else run_speed)


func set_motion(direction: Vector2, is_walking: bool, next_facing: StringName) -> void:
	var next_state: StringName = &"idle" if direction.is_zero_approx() else &"walk" if is_walking else &"run"
	if next_state not in MOTION_STATES:
		next_state = &"idle"
	if next_facing not in DIRECTIONS:
		next_facing = facing
	motion_state = next_state
	facing = next_facing
	_play_animation()


func _play_animation() -> void:
	if animation_player == null:
		return
	var safe_state: StringName = motion_state if motion_state in MOTION_STATES else &"idle"
	var safe_direction: StringName = facing if facing in DIRECTIONS else &"down"
	var next_animation := StringName("%s_%s" % [safe_state, safe_direction])
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


func _show_selection_popup(source: PlayerBackpack.ActiveHandSource) -> void:
	var container_id: StringName = (
		&"toolbar"
		if source == PlayerBackpack.ActiveHandSource.TOOLBAR
		else &"itembar" if source == PlayerBackpack.ActiveHandSource.ITEMBAR else &""
	)
	if backpack == null or container_id == &"":
		return
	var capacity := backpack.capacity(container_id)
	var selected_index := backpack.selected_index(container_id)
	for child: Node in selection_slots.get_children():
		child.free()
	for index: int in capacity:
		var backpack_slot := backpack.get_slot(container_id, index)
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


func consume_energy(amount: int) -> bool:
	if amount < 0 or energy < amount:
		return false
	energy -= amount
	return true


func collect_item(item_meta: ItemMeta, amount: int) -> int:
	if (
		backpack == null
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
	if accepted_by_itembar > 0 and backpack.active_hand_source == PlayerBackpack.ActiveHandSource.ITEMBAR:
		var active := backpack.active_slot()
		EventBus.active_hand_changed.emit(int(backpack.active_hand_source), active.item_id, active.amount)
	var accepted := accepted_by_itembar + accepted_by_inventory
	if accepted > 0:
		AudioManager.play_audio(&"pickup")
	return accepted


func _begin_hold() -> void:
	if backpack == null:
		return
	var item := backpack.active_item()
	if item == null:
		return
	if item.has_method("begin_charge") and item.begin_charge() == OK:
		_refresh_charge_bar()


func _cancel_hold() -> void:
	var active_tool := backpack.active_item() as Tool if backpack != null else null
	if active_tool != null:
		active_tool.cancel_charge()
	_hide_charge_bar()


func _use_tool() -> void:
	if backpack == null:
		return
	var item := backpack.active_item()
	if item == null:
		_cancel_hold()
		_emit_invalid_tool()
		return
	_hide_charge_bar()
	var tool := item as Tool
	if tool == null:
		_emit_invalid_tool()
		return
	var tool_result := tool.use(energy)
	tool.cancel_charge()
	if not tool_result.succeeded():
		_emit_invalid_tool()
		return
	if tool_result.energy_spent > 0:
		if not consume_energy(tool_result.energy_spent):
			_emit_invalid_tool()
			return
		if energy <= 0:
			CalendarManager.next_day()
	if item.meta is SeedMeta:
		var consumed_count := tool_result.cells.size()
		if consumed_count > 0:
			backpack.remove_item(&"itembar", item.meta.id, consumed_count)
			EventBus.container_changed.emit(&"itembar")
			var active := backpack.active_slot()
			EventBus.active_hand_changed.emit(
				int(backpack.active_hand_source),
				active.item_id if active != null and not active.is_empty() else &"",
				active.amount if active != null and not active.is_empty() else 0
			)


func _drop_item() -> void:
	if backpack == null or backpack.active_hand_source == PlayerBackpack.ActiveHandSource.NONE:
		return
	var slot := backpack.active_slot()
	var map: BaseMap = MapManager.current_map()
	var item_meta := DataCatalog.get_item(slot.item_id) if slot != null and not slot.is_empty() else null
	if slot == null or slot.is_empty() or item_meta == null or not item_meta.dropable or map == null:
		return
	var facing_offset: Vector2i = (
		{&"up": Vector2i.UP, &"down": Vector2i.DOWN, &"left": Vector2i.LEFT, &"right": Vector2i.RIGHT}
		. get(facing, Vector2i.DOWN)
	)
	var target_cell: Vector2i = map.world_to_cell(global_position) + facing_offset

	if not map.check_cell(target_cell, CellState.CellCondition.DROPABLE):
		return
	var dropped_item_id := slot.item_id
	var dropped_item := ItemManager.create_from_id(dropped_item_id)
	if dropped_item != null:
		dropped_item.add_flag(ItemMeta.ItemFlag.DROPPED)
	if dropped_item == null or map.add_item(dropped_item, map.cell_to_world(target_cell)) != OK:
		if dropped_item != null:
			dropped_item.free()
		return
	var container_id: StringName = (
		&"toolbar" if backpack.active_hand_source == PlayerBackpack.ActiveHandSource.TOOLBAR else &"itembar"
	)
	if not backpack.remove_item(container_id, dropped_item_id, 1):
		return
	EventBus.container_changed.emit(container_id)
	var active := backpack.active_slot()
	EventBus.active_hand_changed.emit(
		int(backpack.active_hand_source),
		active.item_id if active != null and not active.is_empty() else &"",
		active.amount if active != null and not active.is_empty() else 0
	)


func _emit_invalid_tool() -> void:
	EventBus.request_invalid_feedback.emit(&"invalid_target")
	AudioManager.play_audio(&"invalid")


func _refresh_charge_bar() -> void:
	var active_item := backpack.active_item() if backpack != null else null
	if (
		charge_bar == null
		or active_item == null
		or not active_item.has_method("is_charging")
		or not active_item.is_charging()
	):
		_hide_charge_bar()
		return
	charge_bar.visible = true
	var progress: float = active_item.charge_progress()
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


func _on_interaction_area_entered(area: Area2D) -> void:
	if area == null or not is_instance_valid(area):
		return
	var target := area.get_parent()
	if target is Interactable:
		current_interactable = target
		(target as Interactable).show_bubble()


func _on_interaction_area_exited(area: Area2D) -> void:
	if area == null or not is_instance_valid(area):
		return
	var target := area.get_parent()
	if target is Interactable:
		(target as Interactable).hide_bubble()
	if current_interactable == target:
		current_interactable = null


func _on_house_interior_changed(_house: Node2D, actor: Node2D, active: bool) -> void:
	if actor != null and actor != self:
		return
	if _camera_zoom_tween != null and _camera_zoom_tween.is_valid():
		_camera_zoom_tween.kill()
	var target_zoom := indoor_camera_zoom if active else _outdoor_camera_zoom
	if camera_zoom_duration <= 0.0:
		camera.zoom = target_zoom
	else:
		_camera_zoom_tween = create_tween()
		_camera_zoom_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_camera_zoom_tween.tween_property(camera, "zoom", target_zoom, camera_zoom_duration)


func _on_bar_selection_changed(source: int, _selected_index: int) -> void:
	_show_selection_popup(source as PlayerBackpack.ActiveHandSource)
	AudioManager.play_audio(&"ui_confirm")


func to_dict() -> Dictionary:
	return {
		"position": SerializationUtil.vector2_to_dict(position),
		"facing": String(facing),
		"max_health": max_health,
		"health": health,
		"max_energy": max_energy,
		"energy": energy,
		"gold": gold,
		"backpack": backpack.to_dict() if backpack != null else {},
	}


func from_dict(data: Dictionary) -> Error:
	for key: String in ["facing", "max_health", "health", "max_energy", "energy", "gold"]:
		if key == "facing" and not SerializationUtil.has_valid_string(data, key):
			return ERR_INVALID_DATA
		if key != "facing" and not SerializationUtil.has_valid_int(data, key):
			return ERR_INVALID_DATA
	if not SerializationUtil.has_valid_vector2(data, "position"):
		return ERR_INVALID_DATA
	if (
		int(data.max_health) <= 0
		or int(data.max_energy) <= 0
		or int(data.health) < 0
		or int(data.energy) < 0
		or int(data.gold) < 0
	):
		return ERR_INVALID_DATA
	if not SerializationUtil.has_valid_dictionary(data, "backpack") or backpack == null:
		return ERR_INVALID_DATA
	if backpack.from_dict(data.backpack as Dictionary) != OK:
		return ERR_INVALID_DATA
	position = SerializationUtil.vector2_from_dict(data.position)
	facing = StringName(str(data.facing))
	max_health = int(data.max_health)
	health = mini(int(data.health), max_health)
	max_energy = int(data.max_energy)
	energy = mini(int(data.energy), max_energy)
	gold = int(data.gold)
	return OK
