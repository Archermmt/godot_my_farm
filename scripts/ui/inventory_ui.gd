class_name InventoryUI
extends Control

const INVENTORY_LOCK := &"inventory"
const CONTAINER_ORDER: Array[StringName] = [&"toolbar", &"itembar", &"inventory"]
const SLOT_SCENE := preload("res://scenes/ui/inventory_slot.tscn")

var panel_open := false
var focus_container: StringName = &"toolbar"
var focus_index := 0
var marked_container: StringName = &""
var marked_index := -1
var _slot_nodes: Dictionary[StringName, Array] = {}

@onready var held_status: Label = $HeldStatus/Label
@onready var inventory_panel: ColorRect = $InventoryPanel
@onready var toolbar_slots: HBoxContainer = $InventoryPanel/ToolbarSlots
@onready var itembar_slots: HBoxContainer = $InventoryPanel/ItembarSlots
@onready var inventory_slots: GridContainer = $InventoryPanel/InventorySlots
@onready var detail_label: Label = $InventoryPanel/DetailLabel
@onready var mode_label: Label = $InventoryPanel/ModeLabel


func _ready() -> void:
	var player := SceneManager.registered_player()
	if player != null and player.state != null:
		_build_slots(&"toolbar", toolbar_slots, player.state.toolbar.capacity())
		_build_slots(&"itembar", itembar_slots, player.state.itembar.capacity())
		_build_slots(&"inventory", inventory_slots, player.state.inventory.capacity())
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
	var player := SceneManager.registered_player()
	if player == null or player.state == null:
		return
	if player.lock_input(INVENTORY_LOCK) != OK or GameManager.pause(INVENTORY_LOCK) != OK:
		player.unlock_input(INVENTORY_LOCK)
		return
	panel_open = true
	focus_container = &"toolbar"
	focus_index = player.state.toolbar.selected_index
	inventory_panel.visible = true
	_refresh_all()


func _close_panel() -> void:
	panel_open = false
	inventory_panel.visible = false
	_clear_mark()
	var player := SceneManager.registered_player()
	if player != null and INVENTORY_LOCK in player.input_lock_reasons():
		player.unlock_input(INVENTORY_LOCK)
	if INVENTORY_LOCK in GameManager.pause_reasons():
		GameManager.resume(INVENTORY_LOCK)


func _handle_swap() -> void:
	if marked_container == &"":
		marked_container = focus_container
		marked_index = focus_index
		return
	var player := SceneManager.registered_player()
	var error := player.exchange_container_slots(marked_container, marked_index, focus_container, focus_index) if player != null else ERR_UNCONFIGURED
	mode_label.text = "SWAPPED" if error == OK else "INVALID TARGET"
	_clear_mark(false)


func _confirm_focus() -> void:
	var player := SceneManager.registered_player()
	if player == null:
		return
	if focus_container == &"toolbar":
		player.select_bar_index(PlayerState.ActiveHandSource.TOOLBAR, focus_index)
	elif focus_container == &"itembar":
		player.select_bar_index(PlayerState.ActiveHandSource.ITEMBAR, focus_index)


func _move_horizontal(direction: int) -> void:
	var player := SceneManager.registered_player()
	var container := player.get_container(focus_container) if player != null else null
	if container == null:
		return
	if focus_container == &"inventory":
		var row_start := floori(float(focus_index) / 10.0) * 10
		focus_index = row_start + wrapi((focus_index - row_start) + direction, 0, 10)
	else:
		focus_index = wrapi(focus_index + direction, 0, container.capacity())


func _move_vertical(direction: int) -> void:
	var player := SceneManager.registered_player()
	if player == null or player.state == null:
		return
	if focus_container == &"toolbar":
		focus_container = &"inventory" if direction < 0 else &"itembar"
		focus_index = mini(focus_index, player.get_container(focus_container).capacity() - 1)
	elif focus_container == &"itembar":
		focus_container = &"toolbar" if direction < 0 else &"inventory"
		focus_index = mini(focus_index, player.get_container(focus_container).capacity() - 1)
	else:
		var next_index := focus_index + direction * 10
		if next_index >= 0 and next_index < player.state.inventory.capacity():
			focus_index = next_index
		else:
			focus_container = &"itembar" if direction < 0 else &"toolbar"
			focus_index = mini(focus_index % 10, player.get_container(focus_container).capacity() - 1)


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


func _refresh_all() -> void:
	for container_id: StringName in CONTAINER_ORDER:
		_refresh_container(container_id)
	_refresh_held_status()
	_refresh_details()


func _refresh_container(container_id: StringName) -> void:
	var player := SceneManager.registered_player()
	var container := player.get_container(container_id) if player != null else null
	var nodes: Array = _slot_nodes.get(container_id, []) as Array
	if container == null:
		return
	for index: int in mini(container.capacity(), nodes.size()):
		var slot := nodes[index] as ColorRect
		var label := slot.get_child(0) as Label
		var stack := container.get_slot(index)
		var is_focus := panel_open and focus_container == container_id and focus_index == index
		var is_marked := marked_container == container_id and marked_index == index
		var is_active := (container_id == &"toolbar" and player.state.active_hand_source == PlayerState.ActiveHandSource.TOOLBAR and container.selected_index == index) or (container_id == &"itembar" and player.state.active_hand_source == PlayerState.ActiveHandSource.ITEMBAR and container.selected_index == index)
		slot.color = Color("d75c52") if is_marked else Color("76c7bd") if is_focus else Color("e5b94f") if is_active else Color("244543")
		label.add_theme_color_override("font_color", Color("102827") if is_focus or is_active else Color("eaf0df"))
		label.text = _stack_label(stack)


func _refresh_held_status() -> void:
	var player := SceneManager.registered_player()
	var stack := player.active_stack() if player != null else null
	var source_name := "TOOLS" if player != null and player.state.active_hand_source == PlayerState.ActiveHandSource.TOOLBAR else "ITEMS" if player != null and player.state.active_hand_source == PlayerState.ActiveHandSource.ITEMBAR else "EMPTY"
	if stack == null or stack.is_empty():
		held_status.text = "%s  |  EMPTY" % source_name
		return
	var meta := DataCatalog.get_item(stack.item_id)
	held_status.text = "%s  |  %s%s" % [source_name, meta.display_name if meta != null else String(stack.item_id), " x%d" % stack.amount if stack.amount > 1 else ""]


func _refresh_details() -> void:
	if not panel_open:
		return
	var player := SceneManager.registered_player()
	var container := player.get_container(focus_container) if player != null else null
	var stack := container.get_slot(focus_index) if container != null else null
	if stack == null or stack.is_empty():
		detail_label.text = "%s %02d  |  Empty slot" % [String(focus_container).to_upper(), focus_index + 1]
		return
	var meta := DataCatalog.get_item(stack.item_id)
	if meta == null:
		detail_label.text = String(stack.item_id)
		return
	detail_label.text = "%s x%d  |  %s  |  Buy %d / Sell %d" % [meta.display_name, stack.amount, meta.description, meta.buy_price, meta.sell_price]


func _stack_label(stack: ItemStack) -> String:
	if stack == null or stack.is_empty():
		return "-"
	var meta := DataCatalog.get_item(stack.item_id)
	var display_name := meta.display_name if meta != null else String(stack.item_id)
	var words := display_name.split(" ", false)
	var short := (words[0].left(1) + words[1].left(1)).to_upper() if words.size() >= 2 else display_name.left(2).to_upper()
	return "%s %d" % [short, stack.amount] if stack.amount > 1 else short


func _on_container_changed(_container_id: StringName) -> void:
	_refresh_all()


func _on_bar_selection_changed(_source: int, _selected_index: int) -> void:
	_refresh_all()


func _on_active_hand_changed(_source: int, _item_id: StringName, _amount: int) -> void:
	_refresh_all()
