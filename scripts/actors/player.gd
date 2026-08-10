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

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var camera: Camera2D = $Camera2D
@onready var held_visual: Node2D = $Hands/HeldVisual
@onready var held_swatch: Polygon2D = $Hands/HeldVisual/Swatch
@onready var held_label: Label = $Hands/HeldVisual/Label
@onready var selection_popup: Control = $SelectionPopup
@onready var selection_title: Label = $SelectionPopup/Background/Title
@onready var selection_slots: HBoxContainer = $SelectionPopup/Background/Slots
@onready var selection_timer: Timer = $SelectionTimer


func _ready() -> void:
	assert(walk_speed < run_speed, "walk_speed must be lower than run_speed")
	_play_animation()
	selection_timer.timeout.connect(_hide_selection_popup)
	var event_bus: Variant = _event_bus()
	if event_bus != null and not event_bus.bar_selection_changed.is_connected(_on_bar_selection_changed):
		event_bus.bar_selection_changed.connect(_on_bar_selection_changed)
	if event_bus != null and not event_bus.active_hand_changed.is_connected(_on_active_hand_changed):
		event_bus.active_hand_changed.connect(_on_active_hand_changed)
	if event_bus != null and not event_bus.player_state_changed.is_connected(_on_player_state_changed):
		event_bus.player_state_changed.connect(_on_player_state_changed)
	_refresh_held_visual()


func _unhandled_input(event: InputEvent) -> void:
	if is_input_locked() or not event.is_pressed() or (event is InputEventKey and event.is_echo()):
		return
	if state == null:
		return
	var handled := true
	if event.is_action_pressed("toolbar_previous"):
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


func _physics_process(_delta: float) -> void:
	input_direction = movement_vector()
	walking = wants_walk()
	facing = resolve_facing(input_direction, facing)
	velocity = velocity_for(input_direction, walking)
	move_and_slide()
	set_motion(resolve_motion_state(input_direction, walking), facing)

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
	var catalog: Variant = _data_catalog()
	var meta: ItemMeta = catalog.get_item(stack.item_id) as ItemMeta if catalog != null else null
	if meta == null:
		held_visual.visible = false
		return
	held_visual.visible = true
	held_swatch.color = _item_color(meta)
	held_label.text = _short_label(meta.display_name)


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
			var catalog: Variant = _data_catalog()
			var meta: ItemMeta = catalog.get_item(stack.item_id) as ItemMeta if catalog != null else null
			label.text = _short_label(meta.display_name) if meta != null else "?"
		else:
			label.text = "-"
		slot.add_child(label)
		selection_slots.add_child(slot)
	var selected := container.selected_stack()
	var selected_name := "Empty"
	if selected != null and not selected.is_empty():
		var catalog: Variant = _data_catalog()
		var selected_meta: ItemMeta = catalog.get_item(selected.item_id) as ItemMeta if catalog != null else null
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


func _short_label(display_name: String) -> String:
	var words := display_name.split(" ", false)
	if words.size() >= 2:
		return (words[0].left(1) + words[1].left(1)).to_upper()
	return display_name.left(2).to_upper()


func _event_bus() -> Variant:
	return get_tree().root.get_node_or_null("EventBus")


func _data_catalog() -> Variant:
	return get_tree().root.get_node_or_null("DataCatalog")


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


func select_bar_relative(source: PlayerState.ActiveHandSource, offset: int) -> Error:
	if state == null:
		return ERR_UNCONFIGURED
	var error := state.select_bar_relative(source, offset)
	if error == OK:
		_emit_selection_changed()
	return error


func select_bar_index(source: PlayerState.ActiveHandSource, index: int) -> Error:
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
	var catalog: Variant = _data_catalog()
	var source_meta: ItemMeta = catalog.get_item(source_stack.item_id) if catalog != null and source_stack != null and not source_stack.is_empty() else null
	var target_meta: ItemMeta = catalog.get_item(target_stack.item_id) if catalog != null and target_stack != null and not target_stack.is_empty() else null
	var error := state.exchange_container_slots(source_id, source_index, target_id, target_index, source_meta, target_meta)
	if error == OK:
		_event_bus().container_changed.emit(source_id)
		if source_id != target_id:
			_event_bus().container_changed.emit(target_id)
		_event_bus().active_hand_changed.emit(int(state.active_hand_source), active_stack().item_id if active_stack() != null and not active_stack().is_empty() else &"", active_stack().amount if active_stack() != null and not active_stack().is_empty() else 0)
	return error


func _emit_selection_changed() -> void:
	var container := state.get_container("toolbar" if state.active_hand_source == PlayerState.ActiveHandSource.TOOLBAR else "itembar")
	_event_bus().bar_selection_changed.emit(int(state.active_hand_source), container.selected_index)
	var stack := state.active_stack()
	_event_bus().active_hand_changed.emit(int(state.active_hand_source), stack.item_id if stack != null and not stack.is_empty() else &"", stack.amount if stack != null and not stack.is_empty() else 0)


func _on_player_state_changed(next_state: PlayerState) -> void:
	bind_state(next_state)


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
