extends SceneTree

const MAIN_PATH := "res://scenes/app/main.tscn"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_manager := root.get_node("SceneManager")
	var game_manager := root.get_node("GameManager")
	var main := (load(MAIN_PATH) as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var player: Variant = scene_manager.registered_player()
	var ui: Variant = main.get_node("UILayer/InventoryInterface")
	if player == null or ui == null or player.state.active_hand_source != PlayerState.ActiveHandSource.NONE or not player.active_stack().is_empty() or player.held_visual.visible:
		_fail("initial empty-hand state failed")
		return
	await _tap(&"toolbar_next")
	await _tap(&"toolbar_previous")
	if player.active_stack().item_id != &"tool_hoe" or not player.held_visual.visible:
		_fail("toolbar activation failed")
		return
	await _tap(&"toolbar_next")
	if player.state.toolbar.selected_index != 1 or player.active_stack().item_id != &"tool_watering_can" or not player.selection_popup.visible or not player.held_visual.visible:
		_fail("toolbar keyboard selection failed")
		return
	await _tap(&"itembar_next")
	if player.state.active_hand_source != PlayerState.ActiveHandSource.ITEMBAR or player.active_stack().item_id != &"seed_pumpkin" or not player.held_visual.visible:
		_fail("pumpkin itembar selection failed")
		return
	await _tap(&"itembar_previous")
	if player.active_stack().item_id != &"seed_parsnip" or not player.held_visual.visible:
		_fail("itembar seed selection failed")
		return
	await _tap(&"inventory_toggle")
	if not ui.panel_open or not player.is_input_locked() or not game_manager.is_paused():
		_fail("inventory lock failed")
		return
	if ui.toolbar_slots.get_child_count() != 6 or ui.itembar_slots.get_child_count() != 10 or ui.inventory_slots.get_child_count() != 20:
		_fail("inventory slots were not built after player registration")
		return
	ui.focus_container = &"toolbar"
	ui.focus_index = 1
	await _tap(&"inventory_swap")
	await _tap(&"move_down")
	await _tap(&"inventory_swap")
	if player.state.toolbar.get_slot(1).item_id != &"tool_watering_can" or ui.mode_label.text != "INVALID TARGET":
		_fail("invalid toolbar to itembar exchange mutated state")
		return
	ui.focus_container = &"toolbar"
	ui.focus_index = 1
	await _tap(&"inventory_swap")
	await _tap(&"move_up")
	await _tap(&"inventory_swap")
	if not player.state.toolbar.get_slot(1).is_empty() or player.state.inventory.get_slot(1).item_id != &"tool_watering_can":
		_fail("toolbar to inventory exchange failed")
		return
	ui.focus_container = &"itembar"
	ui.focus_index = 0
	await _tap(&"inventory_swap")
	await _tap(&"move_down")
	await _tap(&"inventory_swap")
	if not player.state.itembar.get_slot(0).is_empty() or player.state.inventory.get_slot(0).item_id != &"seed_parsnip":
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
