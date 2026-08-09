extends ProjectTestCase


func test_status_queries_are_owned_by_map_cell() -> void:
	var cell := MapCell.new(Vector2i(4, 7), MapCell.Status.BASE)
	assert_equal(cell.coordinates, Vector2i(4, 7))
	assert_true(cell.is_walkable())
	assert_true(not cell.is_diggable())
	cell.add_status(MapCell.Status.DIGGABLE)
	assert_true(cell.is_diggable())
	assert_true(cell.can_till())
	cell.add_status(MapCell.Status.DROPABLE)
	assert_true(cell.can_drop())
	cell.add_status(MapCell.Status.BLOCKED)
	assert_true(not cell.is_walkable())
	assert_true(not cell.can_till())
	assert_true(not cell.can_drop())
	cell.remove_status(MapCell.Status.BLOCKED)
	assert_true(cell.is_walkable())


func test_cell_state_is_bound_to_matching_cell() -> void:
	var cell := MapCell.new(Vector2i(3, 2), MapCell.Status.BASE | MapCell.Status.DIGGABLE)
	var wrong_state := CellState.new()
	wrong_state.cell = Vector2i(2, 3)
	assert_equal(cell.bind_state(wrong_state), ERR_INVALID_PARAMETER)
	var state := CellState.new()
	state.cell = cell.coordinates
	state.dug = true
	state.watered_on_day = 5
	assert_equal(cell.bind_state(state), OK)
	assert_true(cell.cell_state() == state)
	assert_true(cell.is_dug())
	assert_true(cell.is_watered(5))
	assert_true(not cell.is_watered(4))
	assert_true(not cell.can_till())
	assert_true(cell.can_water())
	var replacement := CellState.new()
	replacement.cell = cell.coordinates
	assert_equal(cell.bind_state(replacement), OK)
	assert_true(cell.cell_state() == replacement)
	assert_true(not cell.is_dug())


func test_occupancy_prevents_tilling() -> void:
	var cell := MapCell.new(Vector2i.ZERO, MapCell.Status.DIGGABLE)
	var state := CellState.new()
	var entity := EntityState.new()
	entity.instance_id = &"rock_001"
	entity.definition_id = &"rock"
	assert_equal(state.add_entity(entity), OK)
	assert_equal(cell.bind_state(state), OK)
	assert_true(cell.has_occupant())
	assert_true(not cell.can_till())
