extends ProjectTestCase


func test_farm_crop_map_deep_json_round_trip() -> void:
	var crop := CropState.new()
	crop.crop_id = &"crop_parsnip"
	crop.seed_item_id = &"seed_parsnip"
	crop.growth_days = 4
	crop.health = 2
	crop.planted_on_day = 3
	crop.random_seed = 741

	var cell := FarmCellState.new()
	cell.cell = Vector2i(7, -2)
	cell.dug = true
	cell.watered_on_day = 8
	cell.occupant_id = &"crop_7_-2"
	cell.crop = crop

	var entity := WorldEntityState.new()
	entity.instance_id = &"tree_001"
	entity.definition_id = &"tree"
	entity.entity_kind = &"harvestable"
	entity.cell = Vector2i(10, 5)
	entity.health = 3
	entity.random_seed = 99
	entity.flags = [&"persistent", &"blocks"]

	var npc := NpcState.new()
	npc.npc_id = &"npc_villager"
	npc.schedule_id = &"schedule_villager"
	npc.map_id = &"farm"
	npc.cell = Vector2i(12, 8)
	npc.current_event_id = &"morning_farm"

	var map_state := MapState.new()
	map_state.map_id = &"farm"
	map_state.generator_initialized = true
	map_state.set_farm_cell(cell)
	map_state.set_entity(entity)
	map_state.set_npc(npc)

	var parsed: Dictionary = JSON.parse_string(JSON.stringify(map_state.to_dict())) as Dictionary
	var restored := MapState.from_dict(parsed)
	var restored_cell: FarmCellState = restored.farm_cells[Vector2i(7, -2)]
	var restored_entity: WorldEntityState = restored.spawned_entities[&"tree_001"]
	var restored_npc: NpcState = restored.npcs[&"npc_villager"]

	assert_equal(restored.map_id, &"farm")
	assert_equal(typeof(restored.map_id), TYPE_STRING_NAME)
	assert_equal(restored_cell.cell, Vector2i(7, -2))
	assert_equal(typeof(restored_cell.cell), TYPE_VECTOR2I)
	assert_equal(restored_cell.crop.crop_id, &"crop_parsnip")
	assert_equal(restored_cell.crop.growth_days, 4)
	assert_equal(restored_entity.flags, [&"persistent", &"blocks"])
	assert_equal(typeof(restored_entity.flags[0]), TYPE_STRING_NAME)
	assert_equal(restored_npc.schedule_id, &"schedule_villager")
	assert_true(restored.generator_initialized)


func test_watered_state_uses_day_number() -> void:
	var cell := FarmCellState.new()
	cell.watered_on_day = 9
	assert_true(cell.is_watered(9))
	assert_true(not cell.is_watered(10))
