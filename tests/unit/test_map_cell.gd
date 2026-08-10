extends ProjectTestCase


func test_flag_queries_are_owned_by_map_cell() -> void:
	var cell := MapCell.new(Vector2i(4, 7), CellState.CellFlag.BASE)
	assert_equal(cell.coordinates, Vector2i(4, 7))
	assert_true(cell.is_walkable())
	assert_true(not cell.is_diggable())
	cell.add_flag(CellState.CellFlag.DIGGABLE)
	assert_true(cell.is_diggable())
	assert_true(cell.can_till())
	cell.add_flag(CellState.CellFlag.DROPABLE)
	assert_true(cell.can_drop())
	cell.add_flag(CellState.CellFlag.BLOCKED)
	assert_true(not cell.is_walkable())
	assert_true(not cell.can_till())
	assert_true(not cell.can_drop())
	cell.remove_flag(CellState.CellFlag.BLOCKED)
	assert_true(cell.is_walkable())


func test_map_cell_owns_dynamic_state() -> void:
	var cell := MapCell.new(Vector2i(3, 2), CellState.CellFlag.BASE | CellState.CellFlag.DIGGABLE)
	assert_equal(cell.dig(), OK)
	assert_equal(cell.water(), OK)
	assert_true(cell.is_dug())
	assert_true(cell.is_watered())
	assert_true(cell.has_flag(CellState.CellFlag.DUG | CellState.CellFlag.WATERED))
	assert_true(not cell.can_till())
	assert_true(cell.can_water())
	cell.remove_flag(CellState.CellFlag.WATERED)
	assert_true(not cell.is_watered())


func test_occupancy_prevents_tilling() -> void:
	var cell := MapCell.new(Vector2i.ZERO, CellState.CellFlag.DIGGABLE)
	assert_equal(cell.add_item_id(&"rock_001"), OK)
	assert_true(cell.has_occupant())
	assert_true(not cell.can_till())


func test_map_cell_rejects_invalid_or_duplicate_item_id() -> void:
	var cell := MapCell.new(Vector2i(3, 2))
	assert_equal(cell.add_item_id(&""), ERR_INVALID_PARAMETER)
	assert_equal(cell.add_item_id(&"rock_001"), OK)
	assert_equal(cell.add_item_id(&"rock_001"), ERR_ALREADY_EXISTS)
