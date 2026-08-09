extends ProjectTestCase


func test_cell_and_polymorphic_entity_deep_json_round_trip() -> void:
	var crop := CropEntityState.new()
	crop.instance_id = &"crop_7_-2"
	crop.definition_id = &"crop_parsnip"
	crop.cell = Vector2i(7, -2)
	crop.seed_item_id = &"seed_parsnip"
	crop.growth_days = 4
	crop.health = 2
	crop.planted_on_day = 3
	crop.random_seed = 741

	var cell := CellState.new()
	cell.cell = Vector2i(7, -2)
	cell.status = MapCell.Status.BASE | MapCell.Status.DIGGABLE
	cell.dug = true
	cell.watered_on_day = 8

	var entity_cell := CellState.new()
	entity_cell.cell = Vector2i(10, 5)
	var entity := EntityState.new()
	entity.instance_id = &"tree_001"
	entity.definition_id = &"tree"
	entity.entity_kind = &"harvestable"
	entity.cell = Vector2i(10, 5)
	entity.health = 3
	entity.random_seed = 99
	entity.flags = [&"persistent", &"blocks"]

	var map_state := MapState.new()
	map_state.map_id = &"farm"
	map_state.generator_initialized = true
	assert_equal(map_state.set_cell(cell), OK)
	assert_equal(map_state.set_cell(entity_cell), OK)
	assert_equal(map_state.set_entity(crop), OK)
	assert_equal(map_state.set_entity(entity), OK)

	var parsed: Dictionary = JSON.parse_string(JSON.stringify(map_state.to_dict())) as Dictionary
	var restored := MapState.from_dict(parsed)
	var restored_cell: CellState = restored.cells[Vector2i(7, -2)]
	var restored_crop: EntityState = restored_cell.get_entity(&"crop_7_-2")
	var restored_entity: EntityState = restored.cells[Vector2i(10, 5)].get_entity(&"tree_001")

	assert_equal(restored.map_id, &"farm")
	assert_equal(typeof(restored.map_id), TYPE_STRING_NAME)
	assert_equal(restored_cell.cell, Vector2i(7, -2))
	assert_equal(typeof(restored_cell.cell), TYPE_VECTOR2I)
	assert_true(restored_crop is CropEntityState)
	assert_equal(restored_crop.definition_id, &"crop_parsnip")
	assert_equal((restored_crop as CropEntityState).growth_days, 4)
	assert_true(restored_cell.has_entity(&"crop_7_-2"))
	assert_equal(restored_entity.flags, [&"persistent", &"blocks"])
	assert_equal(typeof(restored_entity.flags[0]), TYPE_STRING_NAME)
	assert_true(restored.generator_initialized)


func test_map_state_moves_entity_between_cells() -> void:
	var source := CellState.new()
	source.cell = Vector2i(1, 1)
	var target := CellState.new()
	target.cell = Vector2i(2, 1)
	var entity := EntityState.new()
	entity.instance_id = &"log_001"
	entity.definition_id = &"log"
	entity.cell = source.cell
	var map_state := MapState.new()
	assert_equal(map_state.set_cell(source), OK)
	assert_equal(map_state.set_cell(target), OK)
	assert_equal(map_state.set_entity(entity), OK)
	var duplicate := EntityState.new()
	duplicate.instance_id = entity.instance_id
	duplicate.definition_id = &"duplicate"
	duplicate.cell = target.cell
	assert_equal(map_state.set_entity(duplicate), ERR_ALREADY_EXISTS)
	assert_equal(map_state.move_entity(entity.instance_id, target.cell), OK)
	assert_true(not source.has_entity(entity.instance_id))
	assert_true(target.get_entity(entity.instance_id) == entity)
	assert_equal(entity.cell, target.cell)


func test_watered_state_uses_day_number() -> void:
	var cell := CellState.new()
	cell.watered_on_day = 9
	assert_true(cell.is_watered(9))
	assert_true(not cell.is_watered(10))
