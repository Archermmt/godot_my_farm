class_name FarmPlayer
extends CharacterBody2D

const DIRECTIONS := [&"down", &"left", &"right", &"up"]
const MOTION_STATES := [&"idle", &"walk", &"run"]

@export_range(1.0, 500.0, 1.0) var run_speed: float = 96.0
@export_range(1.0, 500.0, 1.0) var walk_speed: float = 48.0

var input_direction: Vector2 = Vector2.ZERO
var facing: StringName = &"down"
var motion_state: StringName = &"idle"
var walking: bool = false
var state: PlayerState = null

var _lock_reasons: Dictionary[StringName, bool] = {}
var _event_bus_service: EventBusService = null
var _catalog_service: DataCatalogService = null
var _scene_manager_service: SceneManagerService = null
var _audio_manager_service: AudioManagerService = null
var _interaction_move_cooldown: float = 0.0
var _interaction_move_direction: Vector2i = Vector2i.ZERO

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var camera: Camera2D = $Camera2D
@onready var held_visual: Node2D = $Hands/HeldVisual
@onready var held_swatch: Polygon2D = $Hands/HeldVisual/Swatch
@onready var held_label: Label = $Hands/HeldVisual/Label
@onready var selection_popup: Control = $SelectionPopup
@onready var selection_title: Label = $SelectionPopup/Background/Title
@onready var selection_slots: HBoxContainer = $SelectionPopup/Background/Slots
@onready var selection_timer: Timer = $SelectionTimer
@onready var interaction_cursor: InteractionCursor = $InteractionCursor
@onready var collect_area: Area2D = $CollectArea


func _ready() -> void:
	assert(walk_speed < run_speed, "walk_speed must be lower than run_speed")
	configure(EventBus, DataCatalog, SceneManager, AudioManager)
	_play_animation()
	selection_timer.timeout.connect(_hide_selection_popup)
	_refresh_held_visual()


func configure(
	event_bus_service: EventBusService,
	catalog_service: DataCatalogService,
	scene_manager_service: SceneManagerService,
	audio_manager_service: AudioManagerService
) -> void:
	_event_bus_service = event_bus_service
	_catalog_service = catalog_service
	_scene_manager_service = scene_manager_service
	_audio_manager_service = audio_manager_service
	interaction_cursor.configure(event_bus_service)
	if _event_bus_service != null and not _event_bus_service.bar_selection_changed.is_connected(_on_bar_selection_changed):
		_event_bus_service.bar_selection_changed.connect(_on_bar_selection_changed)
	if _event_bus_service != null and not _event_bus_service.active_hand_changed.is_connected(_on_active_hand_changed):
		_event_bus_service.active_hand_changed.connect(_on_active_hand_changed)
	if _event_bus_service != null and not _event_bus_service.player_state_changed.is_connected(_on_player_state_changed):
		_event_bus_service.player_state_changed.connect(_on_player_state_changed)


func _unhandled_input(event: InputEvent) -> void:
	if state == null:
		return
	if event.is_action_released("use_held"):
		_release_interaction()
		get_viewport().set_input_as_handled()
		return
	if is_input_locked() or not event.is_pressed() or (event is InputEventKey and event.is_echo()):
		return
	var handled := true
	if event.is_action_pressed("use_held"):
		_begin_interaction()
	elif event.is_action_pressed("skip_day"):
		GameManager.skip_day()
	elif event.is_action_pressed("drop_held"):
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


func _process(delta: float) -> void:
	if interaction_cursor == null:
		return
	if interaction_cursor.is_charging() and is_input_locked():
		_cancel_interaction()
		return
	interaction_cursor.update(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_interaction()


func _physics_process(delta: float) -> void:
	input_direction = movement_vector()
	walking = wants_walk()
	if interaction_cursor != null and interaction_cursor.is_charging():
		_process_interaction_grid_move(delta)
		velocity = Vector2.ZERO
		set_motion(&"idle", facing)
		_sync_state_cell()
		return
	else:
		facing = resolve_facing(input_direction, facing)
	velocity = velocity_for(input_direction, walking)
	move_and_slide()
	set_motion(resolve_motion_state(input_direction, walking), facing)
	_sync_state_cell()
	_process_pickups(delta)


func _process_pickups(delta: float) -> void:
	var map: BaseMap = _scene_manager_service.current_map() if _scene_manager_service != null else null
	if map == null or collect_area == null:
		return
	map.collect_pickups(self, global_position, 72.0, delta)


func _process_interaction_grid_move(delta: float) -> void:
	_interaction_move_cooldown = maxf(0.0, _interaction_move_cooldown - delta)
	var direction: Vector2i = _cardinal_input_direction(input_direction)
	if direction == Vector2i.ZERO:
		_interaction_move_direction = Vector2i.ZERO
		return
	if direction == _interaction_move_direction and _interaction_move_cooldown > 0.0:
		return
	_interaction_move_direction = direction
	_interaction_move_cooldown = 0.14
	var map: BaseMap = _scene_manager_service.current_map() if _scene_manager_service != null else null
	if map == null or state == null:
		return
	var target_cell: Vector2i = state.cell + direction
	if not map.contains_cell(target_cell) or not map.is_walkable(target_cell):
		return
	var target_position := map.cell_to_world_center(target_cell)
	var movement := target_position - global_position
	if test_move(global_transform, movement):
		return
	global_position = target_position
	interaction_cursor.move_origin(target_cell)


func _cardinal_input_direction(direction: Vector2) -> Vector2i:
	if is_zero_approx(direction.x) and is_zero_approx(direction.y):
		return Vector2i.ZERO
	if absf(direction.x) >= absf(direction.y):
		return Vector2i(signi(roundi(direction.x)), 0)
	return Vector2i(0, signi(roundi(direction.y)))

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
	if interaction_cursor != null and interaction_cursor.is_charging():
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
	var active_stack: ItemStack = state.active_stack() if state != null else null
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
		"held_visual_visible": held_visual.visible,
		"selection_popup_visible": selection_popup.visible,
	}


func _on_bar_selection_changed(source: int, _selected_index: int) -> void:
	_show_selection_popup(source as PlayerState.ActiveHandSource)


func _on_active_hand_changed(_source: int, _item_id: StringName, _amount: int) -> void:
	_refresh_held_visual()


func _refresh_held_visual() -> void:
	if held_visual == null:
		return
	var stack: ItemStack = state.active_stack() if state != null else null
	if stack == null or stack.is_empty():
		held_visual.visible = false
		return
	var meta: ItemMeta = _catalog_service.get_item(stack.item_id) if _catalog_service != null else null
	if meta == null:
		held_visual.visible = false
		return
	held_visual.visible = true
	held_swatch.color = _item_color(meta)
	held_label.text = _short_label(meta)


func _show_selection_popup(source: PlayerState.ActiveHandSource) -> void:
	if state == null:
		return
	var container: InventoryState = state.toolbar if source == PlayerState.ActiveHandSource.TOOLBAR else state.itembar if source == PlayerState.ActiveHandSource.ITEMBAR else null
	if container == null:
		return
	for child: Node in selection_slots.get_children():
		child.free()
	for index: int in container.capacity():
		var stack := container.get_slot(index)
		var slot := ColorRect.new()
		slot.custom_minimum_size = Vector2(17, 17)
		slot.color = Color("f2c14e") if index == container.selected_index else Color("284a48")
		var label := Label.new()
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 7)
		label.add_theme_color_override("font_color", Color("142c2b") if index == container.selected_index else Color("e9f0df"))
		if stack != null and not stack.is_empty():
			var meta: ItemMeta = _catalog_service.get_item(stack.item_id) if _catalog_service != null else null
			label.text = _short_label(meta) if meta != null else "?"
		else:
			label.text = "-"
		slot.add_child(label)
		selection_slots.add_child(slot)
	var selected := container.selected_stack()
	var selected_name := "Empty"
	if selected != null and not selected.is_empty():
		var selected_meta: ItemMeta = _catalog_service.get_item(selected.item_id) if _catalog_service != null else null
		selected_name = selected_meta.display_name if selected_meta != null else String(selected.item_id)
	selection_title.text = "%s  %s" % ["TOOLS" if source == PlayerState.ActiveHandSource.TOOLBAR else "ITEMS", selected_name]
	selection_popup.visible = true
	selection_timer.start()


func _hide_selection_popup() -> void:
	selection_popup.visible = false


func _item_color(meta: ItemMeta) -> Color:
	match meta.item_type:
		ItemMeta.ItemType.TOOL:
			return Color("e1a447")
		ItemMeta.ItemType.SEED:
			return Color("73ad57")
		ItemMeta.ItemType.FOOD:
			return Color("d96c5f")
	return Color("6f9ca0")


func _short_label(meta: ItemMeta) -> String:
	if meta == null:
		return "?"
	var words := meta.display_name.split(" ", false)
	if meta.item_type == ItemMeta.ItemType.SEED and not words.is_empty():
		return words[0].left(2).to_upper()
	if words.size() >= 2:
		return (words[0].left(1) + words[1].left(1)).to_upper()
	return meta.display_name.left(2).to_upper()


func bind_state(next_state: PlayerState) -> Error:
	if next_state == null:
		return ERR_INVALID_PARAMETER
	state = next_state
	facing = state.facing
	_refresh_held_visual()
	return OK


func get_container(container_id: StringName) -> InventoryState:
	return state.get_container(container_id) if state != null else null


func active_stack() -> ItemStack:
	return state.active_stack() if state != null else null


func collect_item(item_meta: ItemMeta, amount: int) -> int:
	if state == null or item_meta == null or item_meta.is_tool() or amount <= 0 or not state.itembar.accepts(item_meta):
		return 0
	var accepted_by_itembar := state.itembar.add_item_partial(item_meta.id, amount, item_meta.stack_limit)
	var remaining := amount - accepted_by_itembar
	var accepted_by_inventory := state.inventory.add_item_partial(item_meta.id, remaining, item_meta.stack_limit) if remaining > 0 else 0
	if _event_bus_service != null:
		if accepted_by_itembar > 0:
			_event_bus_service.container_changed.emit(&"itembar")
		if accepted_by_inventory > 0:
			_event_bus_service.container_changed.emit(&"inventory")
		if accepted_by_itembar > 0 and state.active_hand_source == PlayerState.ActiveHandSource.ITEMBAR:
			var active := state.active_stack()
			_event_bus_service.active_hand_changed.emit(int(state.active_hand_source), active.item_id, active.amount)
	return accepted_by_itembar + accepted_by_inventory


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
	var source := state.get_container(source_id)
	var target := state.get_container(target_id)
	if source == null or target == null:
		return ERR_INVALID_PARAMETER
	var source_stack := source.get_slot(source_index)
	var target_stack := target.get_slot(target_index)
	var source_meta: ItemMeta = _catalog_service.get_item(source_stack.item_id) if _catalog_service != null and source_stack != null and not source_stack.is_empty() else null
	var target_meta: ItemMeta = _catalog_service.get_item(target_stack.item_id) if _catalog_service != null and target_stack != null and not target_stack.is_empty() else null
	var error := state.exchange_container_slots(source_id, source_index, target_id, target_index, source_meta, target_meta)
	if error == OK:
		_event_bus_service.container_changed.emit(source_id)
		if source_id != target_id:
			_event_bus_service.container_changed.emit(target_id)
		_event_bus_service.active_hand_changed.emit(int(state.active_hand_source), active_stack().item_id if active_stack() != null and not active_stack().is_empty() else &"", active_stack().amount if active_stack() != null and not active_stack().is_empty() else 0)
	return error


func _emit_selection_changed() -> void:
	var container := state.get_container("toolbar" if state.active_hand_source == PlayerState.ActiveHandSource.TOOLBAR else "itembar")
	_event_bus_service.bar_selection_changed.emit(int(state.active_hand_source), container.selected_index)
	var stack := state.active_stack()
	_event_bus_service.active_hand_changed.emit(int(state.active_hand_source), stack.item_id if stack != null and not stack.is_empty() else &"", stack.amount if stack != null and not stack.is_empty() else 0)


func _on_player_state_changed(next_state: PlayerState) -> void:
	_cancel_interaction()
	bind_state(next_state)


func _begin_interaction() -> void:
	if interaction_cursor == null or state == null:
		return
	var stack := state.active_stack()
	if stack == null or stack.is_empty():
		return
	var meta: ItemMeta = _catalog_service.get_item(stack.item_id) if _catalog_service != null else null
	var map: BaseMap = _scene_manager_service.current_map() if _scene_manager_service != null else null
	if meta == null or map == null:
		return
	var player_cell := map.world_to_cell(global_position)
	state.cell = player_cell
	_interaction_move_cooldown = 0.0
	_interaction_move_direction = Vector2i.ZERO
	interaction_cursor.begin(state, map, meta)


func _sync_state_cell() -> void:
	if state == null:
		return
	var map: BaseMap = _scene_manager_service.current_map() if _scene_manager_service != null else null
	if map == null:
		return
	var current_cell := map.world_to_cell(global_position)
	if not map.contains_cell(current_cell):
		return
	state.cell = current_cell
	if interaction_cursor != null and interaction_cursor.is_charging():
		interaction_cursor.move_origin(current_cell)


func _release_interaction() -> void:
	if interaction_cursor != null:
		var error := interaction_cursor.release()
		_reset_interaction_grid_move()
		if error != OK:
			return
		if interaction_cursor.last_tool_outcome != null:
			var result := interaction_cursor.last_tool_outcome
			var stamina_spent := result.stamina_spent
			if stamina_spent > 0 and state != null and state.consume_energy(stamina_spent):
				if state.stamina <= 0:
					GameManager.request_end_day()
			_emit_tool_outcome(result)
		elif interaction_cursor.last_seed_outcome != null:
			var seed_outcome := interaction_cursor.last_seed_outcome
			if seed_outcome.consumed_count() > 0 and state != null:
				state.itembar.remove_item(seed_outcome.seed_item_id, seed_outcome.consumed_count())
				_event_bus_service.container_changed.emit(&"itembar")
				var active := state.active_stack()
				_event_bus_service.active_hand_changed.emit(int(state.active_hand_source), active.item_id, active.amount)


func _drop_held_item() -> void:
	if state == null or state.active_hand_source != PlayerState.ActiveHandSource.ITEMBAR:
		return
	var stack := state.active_stack()
	var map: BaseMap = _scene_manager_service.current_map() if _scene_manager_service != null else null
	if stack == null or stack.is_empty() or map == null:
		return
	var facing_offset: Vector2i = InteractionCursor.FACING_VECTORS.get(state.facing, Vector2i.DOWN)
	var target_cell: Vector2i = map.world_to_cell(global_position) + facing_offset
	if not map.check_cell(target_cell, BaseMap.CellCondition.DROPABLE):
		return
	var dropped_item_id := stack.item_id
	if map.spawn_pickup(dropped_item_id, target_cell) == &"":
		return
	state.itembar.remove_item(dropped_item_id, 1)
	if _event_bus_service != null:
		_event_bus_service.container_changed.emit(&"itembar")
		var active := state.active_stack()
		_event_bus_service.active_hand_changed.emit(int(state.active_hand_source), active.item_id, active.amount)


func _emit_tool_outcome(result: ToolOutcome) -> void:
	if result == null or _event_bus_service == null:
		return
	_event_bus_service.cells_tool_used.emit(result.tool_kind, result.effect_cells, result.stamina_spent)
	if result is CellToolOutcome:
		var cell_result := result as CellToolOutcome
		if cell_result.projection_error != OK:
			_event_bus_service.cell_projection_failed.emit(cell_result.effect_cells, cell_result.projection_error)
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
	_event_bus_service.request_tool_feedback.emit(event_id, result.effect_cells)
	if _audio_manager_service != null:
		_audio_manager_service.play_event(event_id)


func _cancel_interaction() -> void:
	if interaction_cursor != null:
		interaction_cursor.cancel()
	_reset_interaction_grid_move()


func _reset_interaction_grid_move() -> void:
	_interaction_move_cooldown = 0.0
	_interaction_move_direction = Vector2i.ZERO


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
