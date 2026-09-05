class_name InventoryUI
extends Control

const INVENTORY_LOCK := &"inventory"
const CONTAINER_ORDER: Array[StringName] = [&"toolbar", &"itembar", &"main_space"]
const SLOT_SCENE := preload("res://scenes/ui/inventory_slot.tscn")

var panel_open := false
var focus_container: StringName = &"toolbar"
var focus_index := 0
var marked_container: StringName = &""
var marked_index := -1
var _slot_nodes: Dictionary[StringName, Array] = {}

@onready var inventory_panel: ColorRect = $InventoryPanel
@onready var toolbar_slots: HBoxContainer = $InventoryPanel/ToolbarSlots
@onready var itembar_slots: HBoxContainer = $InventoryPanel/ItembarSlots
@onready var inventory_slots: GridContainer = $InventoryPanel/InventorySlots
@onready var detail_label: Label = $InventoryPanel/DetailLabel
@onready var mode_label: Label = $InventoryPanel/ModeLabel


func _ready() -> void:
	var player := GameManager.player
	_ensure_slots(player)
	if not EventBus.container_changed.is_connected(_on_container_changed):
		EventBus.container_changed.connect(_on_container_changed)
	if not EventBus.bar_selection_changed.is_connected(_on_bar_selection_changed):
		EventBus.bar_selection_changed.connect(_on_bar_selection_changed)
	if not EventBus.active_hand_changed.is_connected(_on_active_hand_changed):
		EventBus.active_hand_changed.connect(_on_active_hand_changed)
	inventory_panel.visible = false
	_refresh_all()


func _exit_tree() -> void:
	if panel_open:
		_close_panel()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or (event is InputEventKey and event.is_echo()):
		return
	if event.is_action_pressed("inventory_toggle"):
		_toggle_panel()
		get_viewport().set_input_as_handled()
		return
	if not panel_open:
		return
	if event.is_action_pressed("cancel"):
		if marked_container != &"":
			_clear_mark()
		else:
			_close_panel()
	elif event.is_action_pressed("inventory_swap"):
		_handle_swap()
	elif event.is_action_pressed("inventory_confirm"):
		_confirm_focus()
	elif event.is_action_pressed("move_left"):
		_move_horizontal(-1)
	elif event.is_action_pressed("move_right"):
		_move_horizontal(1)
	elif event.is_action_pressed("move_up"):
		_move_vertical(-1)
	elif event.is_action_pressed("move_down"):
		_move_vertical(1)
	else:
		return
	_refresh_all()
	get_viewport().set_input_as_handled()


func _toggle_panel() -> void:
	if panel_open:
		_close_panel()
	else:
		_open_panel()


func _open_panel() -> void:
	var player := GameManager.player
	if player == null or player.state == null:
		return
	_ensure_slots(player)
	if player.lock_input(INVENTORY_LOCK) != OK or CalendarManager.pause(INVENTORY_LOCK) != OK:
		player.unlock_input(INVENTORY_LOCK)
		return
	panel_open = true
	focus_container = &"toolbar"
	focus_index = player.backpack.selected_index(&"toolbar")
	inventory_panel.visible = true
	AudioManager.play_audio(&"ui_confirm")
	_refresh_all()


func _close_panel() -> void:
	panel_open = false
	inventory_panel.visible = false
	_clear_mark()
	var player := GameManager.player
	if player != null and INVENTORY_LOCK in player.input_lock_reasons():
		player.unlock_input(INVENTORY_LOCK)
	if INVENTORY_LOCK in CalendarManager.pause_reasons():
		CalendarManager.resume(INVENTORY_LOCK)
	AudioManager.play_audio(&"ui_cancel")


func _handle_swap() -> void:
	if marked_container == &"":
		marked_container = focus_container
		marked_index = focus_index
		return
	var player := GameManager.player
	var error := (
		player.backpack.exchange_container_slots(marked_container, marked_index, focus_container, focus_index)
		if player != null and player.backpack != null
		else ERR_UNCONFIGURED
	)
	mode_label.text = "SWAPPED" if error == OK else "INVALID TARGET"
	if error == OK:
		AudioManager.play_audio(&"ui_confirm")
	else:
		AudioManager.play_audio(&"invalid")
		EventBus.request_invalid_feedback.emit(&"invalid_target")
	_clear_mark(false)


func _confirm_focus() -> void:
	var player := GameManager.player
	if player == null or player.backpack == null:
		return
	if focus_container == &"toolbar":
		if not player.backpack.select_bar_index(BackpackState.ActiveHandSource.TOOLBAR, focus_index):
			AudioManager.play_audio(&"invalid")
	elif focus_container == &"itembar":
		if not player.backpack.select_bar_index(BackpackState.ActiveHandSource.ITEMBAR, focus_index):
			AudioManager.play_audio(&"invalid")


func _move_horizontal(direction: int) -> void:
	var player := GameManager.player
	var backpack_state := player.backpack.backpack_state if player != null and player.backpack != null else null
	if backpack_state == null:
		return
	if focus_container == &"main_space":
		var columns := 6
		var row_start := floori(float(focus_index) / columns) * columns
		var row_size := mini(columns, backpack_state.capacity(&"main_space") - row_start)
		if row_size > 0:
			focus_index = row_start + wrapi((focus_index - row_start) + direction, 0, row_size)
	else:
		focus_index = wrapi(focus_index + direction, 0, backpack_state.capacity(focus_container))


func _move_vertical(direction: int) -> void:
	var player := GameManager.player
	if player == null or player.state == null:
		return
	if focus_container == &"toolbar":
		focus_container = &"main_space" if direction < 0 else &"itembar"
		focus_index = mini(focus_index, player.backpack.backpack_state.capacity(focus_container) - 1)
	elif focus_container == &"itembar":
		focus_container = &"toolbar" if direction < 0 else &"main_space"
		focus_index = mini(focus_index, player.backpack.backpack_state.capacity(focus_container) - 1)
	else:
		var columns := 6
		var next_index := focus_index + direction * columns
		if next_index >= 0 and next_index < player.backpack.backpack_state.capacity(&"main_space"):
			focus_index = next_index
		else:
			focus_container = &"itembar" if direction < 0 else &"toolbar"
		focus_index = mini(focus_index % 6, player.backpack.backpack_state.capacity(focus_container) - 1)


func _clear_mark(reset_mode: bool = true) -> void:
	marked_container = &""
	marked_index = -1
	if reset_mode and mode_label != null:
		mode_label.text = "X MARK/SWAP   F HOLD   ESC CLOSE"


func _build_slots(container_id: StringName, parent: Container, count: int) -> void:
	var nodes: Array = []
	for index: int in count:
		var slot := SLOT_SCENE.instantiate() as ColorRect
		parent.add_child(slot)
		nodes.append(slot)
	_slot_nodes[container_id] = nodes


func _ensure_slots(player: FarmPlayer) -> void:
	if player == null or player.state == null:
		return
	_ensure_container_slots(&"toolbar", toolbar_slots, player.backpack.backpack_state.capacity(&"toolbar"))
	_ensure_container_slots(&"itembar", itembar_slots, player.backpack.backpack_state.capacity(&"itembar"))
	_ensure_container_slots(&"main_space", inventory_slots, player.backpack.backpack_state.capacity(&"main_space"))


func _ensure_container_slots(container_id: StringName, parent: Container, count: int) -> void:
	var nodes: Array = _slot_nodes.get(container_id, []) as Array
	if nodes.size() == count:
		return
	for node: Node in nodes:
		if is_instance_valid(node):
			parent.remove_child(node)
			node.queue_free()
	_build_slots(container_id, parent, count)


func _refresh_all() -> void:
	_ensure_slots(GameManager.player)
	for container_id: StringName in CONTAINER_ORDER:
		_refresh_container(container_id)
	_refresh_details()


func _refresh_container(container_id: StringName) -> void:
	var player := GameManager.player
	var backpack_state := player.backpack.backpack_state if player != null and player.backpack != null else null
	var nodes: Array = _slot_nodes.get(container_id, []) as Array
	if backpack_state == null:
		return
	for index: int in mini(backpack_state.capacity(container_id), nodes.size()):
		var slot := nodes[index] as ColorRect
		var icon := slot.get_node("Icon") as TextureRect
		var amount_label := slot.get_node("Amount") as Label
		var backpack_slot := backpack_state.get_slot(container_id, index)
		var is_focus := panel_open and focus_container == container_id and focus_index == index
		var is_marked := marked_container == container_id and marked_index == index
		var selected_index := player.backpack.selected_index(container_id)
		var is_active := (
			(
				container_id == &"toolbar"
				and backpack_state.active_hand_source == BackpackState.ActiveHandSource.TOOLBAR
				and selected_index == index
			)
			or (
				container_id == &"itembar"
				and backpack_state.active_hand_source == BackpackState.ActiveHandSource.ITEMBAR
				and selected_index == index
			)
		)
		slot.color = (
			Color("d75c52")
			if is_marked
			else Color("76c7bd") if is_focus else Color("e5b94f") if is_active else Color("244543")
		)
		amount_label.add_theme_color_override(
			"font_color", Color("102827") if is_focus or is_active else Color("eaf0df")
		)
		var meta := DataCatalog.get_item(backpack_slot.item_id) if backpack_slot != null and not backpack_slot.is_empty() else null
		icon.texture = meta.icon_texture if meta != null else null
		icon.visible = icon.texture != null
		amount_label.text = str(backpack_slot.amount) if backpack_slot != null and backpack_slot.amount > 1 else ""


func _refresh_details() -> void:
	if not panel_open:
		return
	var player := GameManager.player
	var backpack_state := player.backpack.backpack_state if player != null and player.backpack != null else null
	var slot := backpack_state.get_slot(focus_container, focus_index) if backpack_state != null else null
	if slot == null or slot.is_empty():
		detail_label.text = "%s %02d  |  Empty slot" % [String(focus_container).to_upper(), focus_index + 1]
		return
	var meta := DataCatalog.get_item(slot.item_id)
	if meta == null:
		detail_label.text = String(slot.item_id)
		return
	detail_label.text = (
		"%s x%d  |  %s  |  Buy %d / Sell %d"
		% [meta.display_name, slot.amount, meta.description, meta.buy_price, meta.sell_price]
	)


func _on_container_changed(_container_id: StringName) -> void:
	_refresh_all()


func _on_bar_selection_changed(_source: int, _selected_index: int) -> void:
	_refresh_all()


func _on_active_hand_changed(_source: int, _item_id: StringName, _amount: int) -> void:
	_refresh_all()
