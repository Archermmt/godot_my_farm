extends ProjectTestCase


func test_cell_and_item_state_deep_json_round_trip() -> void:
	var crop := PlantState.new()
	crop.unique_id = &"crop_7_-2"
	crop.meta_id = &"parsnip"
	crop.health = 2
	crop.last_growth_day = 3

	var cell := CellState.new()
	cell.cell = Vector2i(7, -2)
	cell.flags = CellState.CellFlag.DUG | CellState.CellFlag.WATERED
	cell.item_ids = [crop.unique_id]

	var item_cell := CellState.new()
	item_cell.cell = Vector2i(10, 5)
	var item := HarvestableState.new()
	item.unique_id = &"tree_001"
	item.meta_id = &"tree"
	item.health = 3
	item.flags = [ItemMeta.ItemFlag.HURT, ItemMeta.ItemFlag.DESTROYED]
	item_cell.item_ids = [item.unique_id]

	var map_state := MapState.new()
	map_state.map_id = &"farm"
	map_state.generator_initialized = true
	map_state.generation_epoch = 3
	map_state.cells[cell.cell] = cell
	map_state.cells[item_cell.cell] = item_cell
	map_state.items[crop.unique_id] = crop
	map_state.items[item.unique_id] = item

	var parsed: Dictionary = JSON.parse_string(JSON.stringify(map_state.to_dict())) as Dictionary
	var restored := MapState.from_dict(parsed)
	var restored_cell: CellState = restored.cells[Vector2i(7, -2)]
	var restored_crop := restored.items[&"crop_7_-2"] as PlantState
	var restored_item := restored.items[&"tree_001"] as HarvestableState

	assert_equal(restored.map_id, &"farm")
	assert_equal(typeof(restored.map_id), TYPE_STRING_NAME)
	assert_equal(restored_cell.cell, Vector2i(7, -2))
	assert_equal(typeof(restored_cell.cell), TYPE_VECTOR2I)
	assert_equal(restored_cell.flags, CellState.CellFlag.DUG | CellState.CellFlag.WATERED)
	assert_equal(restored_crop.meta_id, &"parsnip")
	assert_equal(restored_crop.health, 2)
	assert_equal(restored_crop.last_growth_day, 3)
	assert_true(restored_item is HarvestableState)
	assert_equal(restored_item.health, 3)
	assert_true(&"crop_7_-2" in restored_cell.item_ids)
	assert_equal(restored_item.flags, [ItemMeta.ItemFlag.HURT, ItemMeta.ItemFlag.DESTROYED])
	assert_true(restored_item.has_flag(ItemMeta.ItemFlag.HURT))
	assert_true(restored.generator_initialized)
	assert_equal(restored.generation_epoch, 3)
func test_dynamic_cell_flags_survive_state_binding() -> void:
	var map := BaseMap.new()
	var cell := MapCell.new()
	map.cells[Vector2i.ZERO] = cell
	var state := CellState.new()
	state.flags = CellState.CellFlag.DUG | CellState.CellFlag.WATERED
	assert_equal(cell.bind_state(state), OK)
	assert_true(map.check_cell(Vector2i.ZERO, CellState.CellCondition.DUG))
	assert_true(map.check_cell(Vector2i.ZERO, CellState.CellCondition.WATERED))
	map.free()
