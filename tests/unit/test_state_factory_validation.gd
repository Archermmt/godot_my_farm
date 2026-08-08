extends ProjectTestCase


func test_item_stack_rejects_invalid_amount_and_missing_id() -> void:
	assert_true(ItemStack.from_dict({"item_id": "material_wood", "amount": "3"}) == null)
	assert_true(ItemStack.from_dict({"item_id": "", "amount": 3}) == null)
	assert_true(ItemStack.from_dict({"item_id": "material_wood", "amount": -1}) == null)


func test_inventory_rejects_invalid_nested_stack_and_selection() -> void:
	assert_true(InventoryState.from_dict({"slots": ["bad"], "selected_index": 0}) == null)
	assert_true(InventoryState.from_dict({
		"slots": [{"item_id": "material_wood", "amount": 2}],
		"selected_index": 4,
	}) == null)


func test_player_and_calendar_reject_out_of_range_state() -> void:
	assert_true(PlayerState.from_dict({"gold": -1}) == null)
	assert_true(PlayerState.from_dict({"cell": {"x": "bad", "y": 0}}) == null)
	assert_true(CalendarState.from_dict({"month": 13}) == null)
	assert_true(CalendarState.from_dict({"minute": 60}) == null)


func test_map_rejects_invalid_nested_state_and_duplicate_ids() -> void:
	assert_true(MapState.from_dict({
		"map_id": "farm",
		"generator_initialized": false,
		"farm_cells": [{"cell": {"x": 0, "y": 0}, "crop": {"crop_id": "missing_seed"}}],
		"spawned_entities": [],
		"npcs": [],
	}) == null)
	var entity: Dictionary = {
		"instance_id": "tree_001",
		"definition_id": "tree",
		"cell": {"x": 1, "y": 2},
	}
	assert_true(MapState.from_dict({
		"map_id": "farm",
		"generator_initialized": true,
		"farm_cells": [],
		"spawned_entities": [entity, entity],
		"npcs": [],
	}) == null)
