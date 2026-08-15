extends ProjectTestCase


func test_backpack_state_uses_named_slots_and_separate_bars() -> void:
	var backpack := BackpackState.new(2, 2, 2)
	assert_equal(backpack.toolbar, [&"toolbar_0", &"toolbar_1"])
	assert_equal(backpack.itembar, [&"itembar_0", &"itembar_1"])
	assert_equal(backpack.get_slot(&"inventory", 0).slot_id, &"inventory_0")
	assert_equal(backpack.add_item_partial(&"itembar", &"seed_pumpkin", 3, 10), 3)
	assert_equal(backpack.get_slot(&"itembar", 0).item_id, &"seed_pumpkin")
	assert_equal(backpack.get_slot(&"itembar", 0).amount, 3)
	assert_equal(backpack.count_item(&"itembar", &"seed_pumpkin"), 3)


func test_backpack_state_switch_and_round_trip() -> void:
	var backpack := BackpackState.new(1, 1, 1)
	backpack.add_item_partial(&"toolbar", &"tool_hoe", 1, 1)
	backpack.add_item_partial(&"inventory", &"material_wood", 2, 20)
	assert_true(backpack.switch_item(&"toolbar", 0, &"inventory", 0))
	assert_equal(backpack.get_slot(&"inventory", 0).item_id, &"tool_hoe")
	assert_equal(backpack.get_slot(&"toolbar", 0).item_id, &"material_wood")
	var restored := BackpackState.from_dict(backpack.to_dict())
	assert_true(restored != null)
	assert_equal(restored.get_slot(&"inventory", 0).item_id, &"tool_hoe")
	assert_equal(restored.get_slot(&"toolbar", 0).item_id, &"material_wood")
