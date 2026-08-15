extends ProjectTestCase


func test_backpack_add_fills_stack_then_empty_slot() -> void:
	var backpack := BackpackState.new(2, 0, 0)
	assert_equal(backpack.add_item_partial(&"inventory", &"material_wood", 7, 5), 7)
	assert_equal(backpack.get_slot(&"inventory", 0).amount, 5)
	assert_equal(backpack.get_slot(&"inventory", 1).amount, 2)
	assert_equal(backpack.count_item(&"inventory", &"material_wood"), 7)


func test_backpack_full_add_and_insufficient_remove_are_atomic() -> void:
	var backpack := BackpackState.new(2, 0, 0)
	assert_equal(backpack.add_item_partial(&"inventory", &"material_wood", 10, 5), 10)
	var before := backpack.to_dict()
	assert_equal(backpack.add_item_partial(&"inventory", &"material_wood", 1, 5), 0)
	assert_equal(backpack.to_dict(), before)
	assert_true(not backpack.remove_item(&"inventory", &"material_wood", 11))
	assert_equal(backpack.to_dict(), before)


func test_backpack_switch_and_selection() -> void:
	var backpack := BackpackState.new(2, 2, 0)
	assert_equal(backpack.add_item_partial(&"toolbar", &"tool_hoe", 1, 1), 1)
	assert_equal(backpack.add_item_partial(&"inventory", &"seed_parsnip", 8, 99), 8)
	assert_true(backpack.switch_item(&"toolbar", 0, &"inventory", 0))
	assert_equal(backpack.get_slot(&"toolbar", 0).item_id, &"seed_parsnip")
	assert_equal(backpack.get_slot(&"inventory", 0).item_id, &"tool_hoe")
	assert_true(backpack.select_bar_index(PlayerState.ActiveHandSource.TOOLBAR, 1))
	assert_equal(backpack.selected_toolbar_index, 1)


func test_backpack_round_trip_preserves_named_slots() -> void:
	var backpack := BackpackState.new(3, 2, 2)
	assert_equal(backpack.add_item_partial(&"itembar", &"seed_parsnip", 12, 99), 12)
	assert_true(backpack.select_bar_index(PlayerState.ActiveHandSource.ITEMBAR, 1))
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(backpack.to_dict())) as Dictionary
	var restored := BackpackState.from_dict(parsed)
	assert_true(restored != null)
	assert_equal(restored.get_slot(&"itembar", 0).item_id, &"seed_parsnip")
	assert_equal(typeof(restored.get_slot(&"itembar", 0).item_id), TYPE_STRING_NAME)
	assert_equal(restored.get_slot(&"itembar", 0).amount, 12)
	assert_equal(restored.selected_itembar_index, 1)
