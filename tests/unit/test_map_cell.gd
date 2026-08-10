extends ProjectTestCase


func test_map_cell_state_and_occupancy_are_sparse() -> void:
	var cell := MapCell.new()
	cell.state.coord = Vector2i(3, 2)
	cell.add_flag(CellState.CellFlag.DUG)
	cell.state.item_ids.append(&"tree_1")
	assert_equal(cell.coord, Vector2i(3, 2))
	assert_true(cell.has_flag(CellState.CellFlag.DUG))
	assert_true(cell.state.item_ids.has(&"tree_1"))
	assert_true(not cell.state.item_ids.is_empty())
