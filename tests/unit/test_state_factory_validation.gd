extends ProjectTestCase


func test_backpack_slot_rejects_invalid_amount_and_missing_id() -> void:
	assert_true(BackpackSlot.from_dict({"slot_id": "inventory_0", "item_id": "material_wood", "amount": "3"}) == null)
	assert_true(BackpackSlot.from_dict({"slot_id": "inventory_0", "item_id": "", "amount": 3}) == null)
	assert_true(BackpackSlot.from_dict({"slot_id": "inventory_0", "item_id": "material_wood", "amount": -1}) == null)


func test_backpack_rejects_invalid_nested_slot() -> void:
	assert_true(BackpackState.from_dict({
		"slots": {"inventory_0": "bad"},
		"toolbar": [],
		"itembar": [],
		"inventory_capacity": 1,
	}) == null)
	assert_true(BackpackState.from_dict({
		"slots": {"inventory_0": {"slot_id": "inventory_0", "item_id": "material_wood", "amount": -1}},
		"toolbar": [],
		"itembar": [],
		"inventory_capacity": 1,
	}) == null)


func test_player_and_calendar_reject_out_of_range_state() -> void:
	assert_true(PlayerState.from_dict({"gold": -1}) == null)
	assert_true(PlayerState.from_dict({"cell": {"x": "bad", "y": 0}}) == null)
	assert_true(PlayerState.from_dict({
		"map_id": "farm", "spawn_id": "default", "facing": "down",
		"cell": {"x": 0, "y": 0}, "max_health": 100, "health": 100,
		"max_stamina": 100, "stamina": 100, "gold": 0, "active_hand_source": 99,
		"backpack": BackpackState.new().to_dict(),
	}) == null)
	assert_true(CalendarState.from_dict({"month": 13}) == null)
	assert_true(CalendarState.from_dict({"minute": 60}) == null)


func test_map_rejects_invalid_nested_state_and_duplicate_ids() -> void:
	assert_true(MapState.from_dict({
		"map_id": "farm",
		"generator_initialized": false,
		"generation_epoch": 0,
		"cells": [{"cell": {"x": 0, "y": 0}, "flags": 1, "item_ids": ["crop_0_0"]}],
		"items": [{"state_type": "plant", "meta_id": "", "instance_id": "crop_0_0", "cell": {"x": 0, "y": 0}, "health": 1, "random_seed": 0, "flags": [], "growth_days": 0, "planted_on_day": 1}],
	}) == null, "MapState accepted malformed nested ItemState")
	var item: Dictionary = {
		"state_type": "harvestable",
		"instance_id": "tree_001",
		"meta_id": "tree",
		"cell": {"x": 1, "y": 2},
		"health": 1,
		"random_seed": 0,
		"flags": [],
	}
	assert_true(MapState.from_dict({
		"map_id": "farm",
		"generator_initialized": true,
		"generation_epoch": 0,
		"cells": [{"cell": {"x": 1, "y": 2}, "flags": 1, "item_ids": []}],
		"items": [item, item],
	}) == null, "MapState accepted duplicate item IDs")


func test_item_state_rejects_missing_meta_id() -> void:
	assert_true(ItemCodec.from_dict({
		"state_type": "plant",
		"instance_id": "crop_1_2",
		"meta_id": "",
		"cell": {"x": 1, "y": 2},
		"health": 1,
		"random_seed": 0,
		"flags": [],
		"growth_days": 0,
		"planted_on_day": 1,
	}) == null, "ItemState accepted missing meta id")


func test_item_state_rejects_unknown_state_type() -> void:
	assert_true(ItemCodec.from_dict({
		"state_type": "unknown",
		"instance_id": "item_1_2",
		"meta_id": "material_wood",
		"cell": {"x": 1, "y": 2},
		"random_seed": 0,
		"flags": [],
	}) == null, "ItemState accepted unknown state type")


func test_base_item_state_round_trip_preserves_base_type() -> void:
	var state := ItemState.new()
	state.instance_id = &"wood_pickup_1"
	state.meta_id = &"material_wood"
	state.random_seed = 12
	var restored := ItemCodec.from_dict(ItemCodec.to_dict(state))
	assert_true(restored != null)
	assert_true(not restored is HarvestableState)
	assert_equal(restored.instance_id, state.instance_id)
	assert_equal(restored.flags, [])
