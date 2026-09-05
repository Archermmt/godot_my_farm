extends ProjectTestCase


func test_flag_queries_are_owned_by_base_map() -> void:
	var map := BaseMap.new()
	var cell := MapCell.new(Vector2i(4, 7), _state(CellState.CellFlag.BASE))
	map.cells[cell.coordinates] = cell
	assert_equal(cell.coordinates, Vector2i(4, 7))
	assert_true(map.check_cell(cell.coordinates, CellState.CellCondition.WALKABLE))
	assert_true(not map.check_cell(cell.coordinates, CellState.CellCondition.DIGGABLE))
	cell.add_flag(CellState.CellFlag.DIGGABLE)
	assert_true(map.check_cell(cell.coordinates, CellState.CellCondition.DIGGABLE))
	assert_true(cell.apply_tool(ToolMeta.ToolKind.HOE, false))
	cell.add_flag(CellState.CellFlag.DROPABLE)
	assert_true(map.check_cell(cell.coordinates, CellState.CellCondition.DROPABLE))
	cell.add_flag(CellState.CellFlag.BLOCKED)
	assert_true(not map.check_cell(cell.coordinates, CellState.CellCondition.WALKABLE))
	assert_true(not cell.apply_tool(ToolMeta.ToolKind.HOE, false))
	assert_true(not map.check_cell(cell.coordinates, CellState.CellCondition.DROPABLE))
	cell.remove_flag(CellState.CellFlag.BLOCKED)
	assert_true(map.check_cell(cell.coordinates, CellState.CellCondition.WALKABLE))
	map.free()


func test_map_cell_owns_dynamic_state() -> void:
	var map := BaseMap.new()
	var cell := MapCell.new(Vector2i(3, 2), _state(CellState.CellFlag.BASE | CellState.CellFlag.DIGGABLE))
	map.cells[cell.coordinates] = cell
	assert_true(cell.apply_tool(ToolMeta.ToolKind.HOE))
	assert_true(cell.apply_tool(ToolMeta.ToolKind.WATERING_CAN))
	assert_true(map.check_cell(cell.coordinates, CellState.CellCondition.DUG))
	assert_true(map.check_cell(cell.coordinates, CellState.CellCondition.WATERED))
	assert_true(cell.has_flag(CellState.CellFlag.DUG | CellState.CellFlag.WATERED))
	assert_true(not cell.apply_tool(ToolMeta.ToolKind.HOE, false))
	assert_true(not cell.apply_tool(ToolMeta.ToolKind.WATERING_CAN, false))
	cell.remove_flag(CellState.CellFlag.WATERED)
	assert_true(cell.apply_tool(ToolMeta.ToolKind.WATERING_CAN, false))
	assert_true(not map.check_cell(cell.coordinates, CellState.CellCondition.WATERED))
	map.free()


func test_occupancy_prevents_tilling() -> void:
	var cell := MapCell.new(Vector2i.ZERO, _state(CellState.CellFlag.DIGGABLE))
	assert_equal(cell.add_item_id(&"rock_001"), OK)
	assert_true(cell.has_occupant())
	assert_true(not cell.apply_tool(ToolMeta.ToolKind.HOE, false))


func test_hoe_waters_cell_immediately_during_rain() -> void:
	var previous_weather := CalendarManager.current_weather
	CalendarManager.current_weather = &"rain"
	var cell := MapCell.new(Vector2i.ZERO, _state(CellState.CellFlag.BASE | CellState.CellFlag.DIGGABLE))
	assert_true(cell.apply_tool(ToolMeta.ToolKind.HOE))
	assert_true(cell.has_flag(CellState.CellFlag.DUG))
	assert_true(cell.has_flag(CellState.CellFlag.WATERED))
	CalendarManager.current_weather = previous_weather


func test_map_cell_rejects_invalid_or_duplicate_item_id() -> void:
	var cell := MapCell.new(Vector2i(3, 2))
	assert_equal(cell.add_item_id(&""), ERR_INVALID_PARAMETER)
	assert_equal(cell.add_item_id(&"rock_001"), OK)
	assert_equal(cell.add_item_id(&"rock_001"), ERR_ALREADY_EXISTS)


func _state(flags: int) -> CellState:
	var result := CellState.new()
	result.flags = flags
	return result
