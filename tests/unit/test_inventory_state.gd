extends ProjectTestCase


func test_add_fills_existing_stack_then_empty_slot() -> void:
	var inventory := InventoryState.new(2)
	assert_true(inventory.add_item(&"material_wood", 7, 5))
	assert_equal(inventory.slots[0].amount, 5)
	assert_equal(inventory.slots[1].amount, 2)
	assert_equal(inventory.count_item(&"material_wood"), 7)


func test_full_inventory_add_is_atomic() -> void:
	var inventory := InventoryState.new(2)
	assert_true(inventory.add_item(&"material_wood", 10, 5))
	var before: Dictionary = inventory.to_dict()
	assert_true(not inventory.add_item(&"material_wood", 1, 5))
	assert_equal(inventory.to_dict(), before)


func test_insufficient_remove_is_atomic() -> void:
	var inventory := InventoryState.new(2)
	assert_true(inventory.add_item(&"material_stone", 3, 99))
	var before: Dictionary = inventory.to_dict()
	assert_true(not inventory.remove_item(&"material_stone", 4))
	assert_equal(inventory.to_dict(), before)
	assert_true(inventory.remove_item(&"material_stone", 3))
	assert_true(inventory.slots[0].is_empty())


func test_merge_and_swap_slots() -> void:
	var inventory := InventoryState.new(3)
	assert_true(inventory.set_slot(0, ItemStack.new(&"material_wood", 2)))
	assert_true(inventory.set_slot(1, ItemStack.new(&"material_wood", 3)))
	assert_true(inventory.set_slot(2, ItemStack.new(&"material_stone", 1)))
	assert_true(inventory.merge_slots(0, 1, 5))
	assert_true(inventory.slots[0].is_empty())
	assert_equal(inventory.slots[1].amount, 5)
	assert_true(inventory.swap_slots(1, 2))
	assert_equal(inventory.slots[1].item_id, &"material_stone")
	assert_equal(inventory.slots[2].item_id, &"material_wood")


func test_merge_over_limit_is_atomic() -> void:
	var inventory := InventoryState.new(2)
	assert_true(inventory.set_slot(0, ItemStack.new(&"material_wood", 3)))
	assert_true(inventory.set_slot(1, ItemStack.new(&"material_wood", 4)))
	var before: Dictionary = inventory.to_dict()
	assert_true(not inventory.merge_slots(0, 1, 5))
	assert_equal(inventory.to_dict(), before)


func test_exchange_across_inventories_and_selection() -> void:
	var player := InventoryState.new(2, &"player")
	var chest := InventoryState.new(2, &"chest")
	assert_true(player.set_slot(0, ItemStack.new(&"tool_hoe", 1)))
	assert_true(chest.set_slot(1, ItemStack.new(&"seed_parsnip", 8)))
	assert_true(player.exchange_with(chest, 0, 1))
	assert_equal(player.slots[0].item_id, &"seed_parsnip")
	assert_equal(chest.slots[1].item_id, &"tool_hoe")
	assert_true(player.select_slot(1))
	assert_equal(player.selected_index, 1)
	assert_true(not player.select_slot(3))
	assert_equal(player.selected_index, 1)


func test_inventory_round_trip_preserves_stack_types() -> void:
	var inventory := InventoryState.new(3, &"player")
	assert_true(inventory.add_item(&"seed_parsnip", 12, 99))
	assert_true(inventory.select_slot(2))
	var json_text: String = JSON.stringify(inventory.to_dict())
	var parsed: Dictionary = JSON.parse_string(json_text) as Dictionary
	var restored := InventoryState.from_dict(parsed)
	assert_equal(restored.owner_id, &"player")
	assert_equal(typeof(restored.owner_id), TYPE_STRING_NAME)
	assert_equal(restored.slots[0].item_id, &"seed_parsnip")
	assert_equal(typeof(restored.slots[0].item_id), TYPE_STRING_NAME)
	assert_equal(restored.slots[0].amount, 12)
	assert_equal(typeof(restored.slots[0].amount), TYPE_INT)
	assert_equal(restored.selected_index, 2)
