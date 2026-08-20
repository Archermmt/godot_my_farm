extends SceneTree

const MAIN_PATH := "res://scenes/app/main.tscn"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var map_manager := root.get_node("MapManager")
	var game_manager := root.get_node("GameManager")
	var main := (load(MAIN_PATH) as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var player: Variant = map_manager.registered_player()
	var ui: Variant = main.get_node("UILayer/InventoryInterface")
	if player == null or ui == null or player.state.active_hand_source != PlayerState.ActiveHandSource.NONE or not player.active_stack().is_empty():
		_fail("initial empty-hand state failed")
		return
	await _tap(&"toolbar_next")
	await _tap(&"toolbar_previous")
	if player.active_stack().item_id != &"hoe":
		_fail("toolbar activation failed")
		return
	await _tap(&"toolbar_next")
	if player.state.backpack_state.selected_toolbar_index != 1 or player.active_stack().item_id != &"watering_can" or not player.selection_popup.visible:
		_fail("toolbar keyboard selection failed")
		return
	await _tap(&"itembar_next")
	if player.state.active_hand_source != PlayerState.ActiveHandSource.ITEMBAR or player.active_stack().item_id != &"pumpkin_seed":
		_fail("pumpkin itembar selection failed")
		return
	await _tap(&"itembar_previous")
	if player.active_stack().item_id != &"parsnip_seed":
		_fail("itembar seed selection failed")
		return
	await _tap(&"inventory_toggle")
	if not ui.panel_open or not player.is_input_locked() or not game_manager.is_paused():
		_fail("inventory lock failed")
		return
	if ui.toolbar_slots.get_child_count() != 6 or ui.itembar_slots.get_child_count() != 10 or ui.inventory_slots.get_child_count() != 20:
		_fail("inventory slots were not built after player registration")
		return
	var toolbar_icon := ui.toolbar_slots.get_child(0).get_node("Icon") as TextureRect
	var itembar_icon := ui.itembar_slots.get_child(0).get_node("Icon") as TextureRect
	var status: Variant = main.get_node("UILayer/GameStatusPanel")
	if toolbar_icon.texture == null or itembar_icon.texture == null:
		_fail("non-empty inventory slots did not render item icons")
		return
	if (status.get_node("Panel/HandIcon") as TextureRect).texture == null or (status.get_node("Panel/WeatherIcon") as TextureRect).texture == null:
		_fail("status panel did not render hand/weather icons")
		return
	ui.focus_container = &"toolbar"
	ui.focus_index = 1
	await _tap(&"inventory_swap")
	await _tap(&"move_down")
	await _tap(&"inventory_swap")
	if player.state.backpack_state.get_slot(&"toolbar", 1).item_id != &"watering_can" or ui.mode_label.text != "INVALID TARGET":
		_fail("invalid toolbar to itembar exchange mutated state")
		return
	ui.focus_container = &"toolbar"
	ui.focus_index = 1
	await _tap(&"inventory_swap")
	await _tap(&"move_up")
	await _tap(&"inventory_swap")
	if not player.state.backpack_state.get_slot(&"toolbar", 1).is_empty() or player.state.backpack_state.get_slot(&"inventory", 1).item_id != &"watering_can":
		_fail("toolbar to inventory exchange failed")
		return
	ui.focus_container = &"itembar"
	ui.focus_index = 0
	await _tap(&"inventory_swap")
	await _tap(&"move_down")
	await _tap(&"inventory_swap")
	if not player.state.backpack_state.get_slot(&"itembar", 0).is_empty() or player.state.backpack_state.get_slot(&"inventory", 0).item_id != &"parsnip_seed":
		_fail("itembar to inventory exchange failed")
		return
	await _tap(&"cancel")
	if ui.panel_open or player.is_input_locked() or game_manager.is_paused():
		_fail("inventory close did not release locks")
		return
	print("[InventoryKeyboardTest] PASS | toolbar/itembar/head-ui/swap/locks")
	main.queue_free()
	await process_frame
	quit(0)


func _tap(action: StringName) -> void:
	var pressed := InputEventAction.new()
	pressed.action = action
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await process_frame
	var released := InputEventAction.new()
	released.action = action
	released.pressed = false
	Input.parse_input_event(released)
	await process_frame


func _fail(message: String) -> void:
	push_error("[InventoryKeyboardTest] %s" % message)
	quit(1)
