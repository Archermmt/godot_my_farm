extends ProjectTestCase


func test_cell_and_item_state_deep_json_round_trip() -> void:
	var crop := PlantState.new()
	crop.instance_id = &"crop_7_-2"
	crop.meta_id = &"crop_parsnip"
	crop.cell = Vector2i(7, -2)
	crop.growth_days = 4
	crop.health = 2
	crop.planted_on_day = 3
	crop.random_seed = 741

	var cell := CellState.new()
	cell.cell = Vector2i(7, -2)
	cell.flags = CellState.CellFlag.BASE | CellState.CellFlag.DIGGABLE | CellState.CellFlag.DUG | CellState.CellFlag.WATERED
	cell.item_ids = [crop.instance_id]

	var item_cell := CellState.new()
	item_cell.cell = Vector2i(10, 5)
	var item := HarvestableState.new()
	item.instance_id = &"tree_001"
	item.meta_id = &"tree"
	item.cell = Vector2i(10, 5)
	item.health = 3
	item.random_seed = 99
	item.flags = [&"persistent", &"blocks"]
	item_cell.item_ids = [item.instance_id]

	var map_state := MapState.new()
	map_state.map_id = &"farm"
	map_state.generator_initialized = true
	map_state.cells[cell.cell] = cell
	map_state.cells[item_cell.cell] = item_cell
	map_state.items[crop.instance_id] = crop
	map_state.items[item.instance_id] = item

	var parsed: Dictionary = JSON.parse_string(JSON.stringify(map_state.to_dict())) as Dictionary
	var restored := MapState.from_dict(parsed)
	var restored_cell: CellState = restored.cells[Vector2i(7, -2)]
	var restored_crop := restored.items[&"crop_7_-2"] as PlantState
	var restored_item := restored.items[&"tree_001"] as HarvestableState

	assert_equal(restored.map_id, &"farm")
	assert_equal(typeof(restored.map_id), TYPE_STRING_NAME)
	assert_equal(restored_cell.cell, Vector2i(7, -2))
	assert_equal(typeof(restored_cell.cell), TYPE_VECTOR2I)
	assert_equal(restored_cell.flags, CellState.CellFlag.BASE | CellState.CellFlag.DIGGABLE | CellState.CellFlag.DUG | CellState.CellFlag.WATERED)
	assert_equal(restored_crop.meta_id, &"crop_parsnip")
	assert_equal(restored_crop.growth_days, 4)
	assert_equal(restored_crop.health, 2)
	assert_equal(restored_crop.planted_on_day, 3)
	assert_true(restored_item is HarvestableState)
	assert_equal(restored_item.health, 3)
	assert_true(&"crop_7_-2" in restored_cell.item_ids)
	assert_equal(restored_item.flags, [&"persistent", &"blocks"])
	assert_equal(typeof(restored_item.flags[0]), TYPE_STRING_NAME)
	assert_true(restored.generator_initialized)
func test_dynamic_cell_flags_survive_state_binding() -> void:
	var cell := MapCell.new()
	var state := CellState.new()
	state.flags = CellState.CellFlag.DUG | CellState.CellFlag.WATERED
	assert_equal(cell.bind_state(state), OK)
	assert_true(cell.is_dug())
	assert_true(cell.is_watered())
