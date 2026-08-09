extends ProjectTestCase


func test_cell_and_entity_state_deep_json_round_trip() -> void:
	var crop := EntityState.new()
	crop.instance_id = &"crop_7_-2"
	crop.definition_id = &"crop_parsnip"
	crop.type = EntityState.EntityType.CROP
	crop.cell = Vector2i(7, -2)
	crop.seed_item_id = &"seed_parsnip"
	crop.growth_days = 4
	crop.health = 2
	crop.planted_on_day = 3
	crop.random_seed = 741

	var cell := CellState.new()
	cell.cell = Vector2i(7, -2)
	cell.flags = CellState.CellFlag.BASE | CellState.CellFlag.DIGGABLE
	cell.dug = true
	cell.watered_on_day = 8
	cell.entity_ids = [crop.instance_id]

	var entity_cell := CellState.new()
	entity_cell.cell = Vector2i(10, 5)
	var entity := EntityState.new()
	entity.instance_id = &"tree_001"
	entity.definition_id = &"tree"
	entity.type = EntityState.EntityType.HARVESTABLE
	entity.cell = Vector2i(10, 5)
	entity.health = 3
	entity.random_seed = 99
	entity.flags = [&"persistent", &"blocks"]
	entity_cell.entity_ids = [entity.instance_id]

	var map_state := MapState.new()
	map_state.map_id = &"farm"
	map_state.generator_initialized = true
	map_state.cells[cell.cell] = cell
	map_state.cells[entity_cell.cell] = entity_cell
	map_state.entities[crop.instance_id] = crop
	map_state.entities[entity.instance_id] = entity

	var parsed: Dictionary = JSON.parse_string(JSON.stringify(map_state.to_dict())) as Dictionary
	var restored := MapState.from_dict(parsed)
	var restored_cell: CellState = restored.cells[Vector2i(7, -2)]
	var restored_crop: EntityState = restored.entities[&"crop_7_-2"]
	var restored_entity: EntityState = restored.entities[&"tree_001"]

	assert_equal(restored.map_id, &"farm")
	assert_equal(typeof(restored.map_id), TYPE_STRING_NAME)
	assert_equal(restored_cell.cell, Vector2i(7, -2))
	assert_equal(typeof(restored_cell.cell), TYPE_VECTOR2I)
	assert_equal(restored_cell.flags, CellState.CellFlag.BASE | CellState.CellFlag.DIGGABLE)
	assert_equal(restored_crop.type, EntityState.EntityType.CROP)
	assert_equal(restored_crop.definition_id, &"crop_parsnip")
	assert_equal(restored_crop.growth_days, 4)
	assert_true(&"crop_7_-2" in restored_cell.entity_ids)
	assert_equal(restored_entity.flags, [&"persistent", &"blocks"])
	assert_equal(typeof(restored_entity.flags[0]), TYPE_STRING_NAME)
	assert_true(restored.generator_initialized)
func test_watered_state_uses_day_number() -> void:
	var cell := MapCell.new()
	var state := CellState.new()
	state.watered_on_day = 9
	assert_equal(cell.bind_state(state), OK)
	assert_true(cell.is_watered(9))
	assert_true(not cell.is_watered(10))
