extends ProjectTestCase


func test_backpack_add_fills_stack_then_empty_slot() -> void:
	var backpack := BackpackState.new(2, 0, 0)
	assert_equal(backpack.add_item(&"main_space", &"wood", 7, 5), 7)
	assert_equal(backpack.get_slot(&"main_space", 0).amount, 5)
	assert_equal(backpack.get_slot(&"main_space", 1).amount, 2)
	assert_equal(backpack.backpack_state.count_item(&"main_space", &"wood"), 7)


func test_backpack_full_add_and_insufficient_remove_are_atomic() -> void:
	var backpack := BackpackState.new(2, 0, 0)
	assert_equal(backpack.add_item(&"main_space", &"wood", 10, 5), 10)
	var before := backpack.to_dict()
	assert_equal(backpack.add_item(&"main_space", &"wood", 1, 5), 0)
	assert_equal(backpack.to_dict(), before)
	assert_true(not backpack.remove_item(&"main_space", &"wood", 11))
	assert_equal(backpack.to_dict(), before)


func test_backpack_switch_and_selection() -> void:
	var backpack := BackpackState.new(2, 2, 0)
	assert_equal(backpack.add_item(&"toolbar", &"hoe", 1, 1), 1)
	assert_equal(backpack.add_item(&"main_space", &"parsnip_seed", 8, 99), 8)
	assert_true(backpack.switch_item(&"toolbar", 0, &"main_space", 0))
	assert_equal(backpack.get_slot(&"toolbar", 0).item_id, &"parsnip_seed")
	assert_equal(backpack.get_slot(&"main_space", 0).item_id, &"hoe")
	assert_true(backpack.select_bar_index(BackpackState.ActiveHandSource.TOOLBAR, 1))
	assert_equal(backpack.selected_ids.get(&"toolbar"), &"toolbar_1")


func test_backpack_round_trip_preserves_named_slots() -> void:
	var backpack := BackpackState.new(3, 2, 2)
	assert_equal(backpack.add_item(&"itembar", &"parsnip_seed", 12, 99), 12)
	assert_true(backpack.select_bar_index(BackpackState.ActiveHandSource.ITEMBAR, 1))
	backpack.active_hand_source = BackpackState.ActiveHandSource.ITEMBAR
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(backpack.to_dict())) as Dictionary
	var restored := BackpackState.from_dict(parsed)
	assert_true(restored != null)
	assert_equal(restored.get_slot(&"itembar", 0).item_id, &"parsnip_seed")
	assert_equal(typeof(restored.get_slot(&"itembar", 0).item_id), TYPE_STRING_NAME)
	assert_equal(restored.get_slot(&"itembar", 0).amount, 12)
	assert_equal(restored.selected_ids.get(&"itembar"), &"itembar_1")
	assert_equal(restored.active_hand_source, BackpackState.ActiveHandSource.ITEMBAR)


func test_tool_slot_moves_and_round_trips_by_item_id() -> void:
	var backpack := BackpackState.new(1, 1, 0)
	var tool_slot := BackpackSlot.new(&"toolbar_0", &"hoe", 1)
	assert_true(backpack.set_slot(&"toolbar", 0, tool_slot))
	assert_true(backpack.switch_item(&"toolbar", 0, &"main_space", 0))
	assert_true(backpack.get_slot(&"toolbar", 0).is_empty())
	assert_equal(backpack.get_slot(&"main_space", 0).item_id, &"hoe")
	var restored := BackpackState.from_dict(backpack.to_dict())
	assert_true(restored != null)
	assert_equal(restored.get_slot(&"main_space", 0).item_id, &"hoe")


func test_removing_a_depleted_stack_compacts_itembar_and_inventory_but_not_toolbar() -> void:
	var backpack := BackpackState.new(3, 3, 3)
	assert_equal(backpack.add_item(&"itembar", &"parsnip_seed", 1, 1), 1)
	assert_equal(backpack.add_item(&"itembar", &"potato_seed", 1, 1), 1)
	assert_equal(backpack.add_item(&"main_space", &"wood", 1, 1), 1)
	assert_equal(backpack.add_item(&"main_space", &"stone", 1, 1), 1)
	assert_equal(backpack.add_item(&"toolbar", &"hoe", 1, 1), 1)
	assert_equal(backpack.add_item(&"toolbar", &"axe", 1, 1), 1)
	assert_true(backpack.remove_item(&"itembar", &"parsnip_seed", 1))
	assert_equal(backpack.get_slot(&"itembar", 0).item_id, &"potato_seed")
	assert_true(backpack.get_slot(&"itembar", 1).is_empty())
	assert_true(backpack.remove_item(&"main_space", &"wood", 1))
	assert_equal(backpack.get_slot(&"main_space", 0).item_id, &"stone")
	assert_true(backpack.remove_item(&"toolbar", &"hoe", 1))
	assert_true(backpack.get_slot(&"toolbar", 0).is_empty())
	assert_equal(backpack.get_slot(&"toolbar", 1).item_id, &"axe")
