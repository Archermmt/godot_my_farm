extends ProjectTestCase


func test_hoe_changes_only_valid_cells_and_reports_skips() -> void:
	var map := _make_map(4, 2, CellState.CellFlag.DIGGABLE)
	map.get_cell(Vector2i(1, 0)).add_item_id(&"rock")
	map.get_cell(Vector2i(2, 0)).state.flags = CellState.CellFlag.BASE
	var player := PlayerState.new()
	player.energy = 20
	var tool := _test_tool(_tool_meta(ToolMeta.ToolKind.HOE, 2))
	var result := tool.use(map, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], player.energy)
	assert_true(result.succeeded())
	assert_equal(result.cells, [Vector2i(0, 0)])
	assert_equal(player.energy, 20)
	assert_true(map.check_cell(Vector2i(0, 0), CellState.CellCondition.DUG))
	assert_equal(map.interaction_revision, 1)
	tool.free()
	map.free()


func test_water_rejects_untilled_and_repeated_cells_without_spending_energy() -> void:
	var map := _make_map(3, 1, CellState.CellFlag.DIGGABLE)
	assert_true(map.get_cell(Vector2i(0, 0)).apply_tool(ToolMeta.ToolKind.HOE))
	assert_true(map.get_cell(Vector2i(1, 0)).apply_tool(ToolMeta.ToolKind.HOE))
	assert_true(map.get_cell(Vector2i(1, 0)).apply_tool(ToolMeta.ToolKind.WATERING_CAN))
	var player := PlayerState.new()
	player.energy = 10
	var tool := _test_tool(_tool_meta(ToolMeta.ToolKind.WATERING_CAN, 1))
	var result := tool.use(map, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], player.energy)
	assert_true(result.succeeded())
	assert_equal(result.cells, [Vector2i(0, 0)])
	assert_equal(player.energy, 10)
	var repeated := tool.use(map, [Vector2i(0, 0)], player.energy)
	assert_true(not repeated.succeeded())
	assert_equal(player.energy, 10)
	tool.free()
	map.free()


func test_multi_cell_tool_use_is_atomic_at_energy_boundaries() -> void:
	for starting_energy: int in [0, 1, 2]:
		var map := _make_map(2, 1, CellState.CellFlag.DIGGABLE)
		var player := PlayerState.new()
		player.energy = starting_energy
		var before := _cell_flags(map)
		var tool := _test_tool(_tool_meta(ToolMeta.ToolKind.HOE, 2))
		var result := tool.use(map, [Vector2i(0, 0), Vector2i(1, 0)], player.energy)
		if starting_energy < 2:
			assert_true(not result.succeeded())
			assert_equal(_cell_flags(map), before)
			assert_equal(player.energy, starting_energy)
			assert_equal(map.interaction_revision, 0)
		else:
			assert_true(result.succeeded())
			assert_equal(result.cells.size(), 2)
			assert_equal(player.energy, starting_energy)
			assert_equal(map.interaction_revision, 1)
			tool.free()
			map.free()


func test_charge_level_multiplies_energy_cost() -> void:
	var meta := _tool_meta(ToolMeta.ToolKind.HOE, 2)
	meta.levels = [ToolLevel.new(), ToolLevel.new(), ToolLevel.new()]
	assert_equal(meta.level_energy_cost(0), 2)
	assert_equal(meta.level_energy_cost(1), 4)
	assert_equal(meta.level_energy_cost(2), 6)


func test_max_charge_hoe_changes_nine_by_nine_for_one_use_cost() -> void:
	var map := _make_map(9, 9, CellState.CellFlag.DIGGABLE)
	var player := PlayerState.new()
	player.energy = 100
	var targets: Array[Vector2i] = []
	for y: int in 9:
		for x: int in 9:
			targets.append(Vector2i(x, y))
	var tool := _test_tool(_tool_meta(ToolMeta.ToolKind.HOE, 2))
	var result := tool.use(map, targets, player.energy)
	assert_true(result.succeeded())
	assert_equal(result.cells.size(), 81)
	assert_equal(player.energy, 100)
	assert_equal(map.interaction_revision, 1)
	tool.free()
	map.free()


func test_tool_result_reports_one_successful_batch() -> void:
	var map := _make_map(3, 1, CellState.CellFlag.DIGGABLE)
	var available_energy := 10
	var tool := _test_tool(_tool_meta(ToolMeta.ToolKind.HOE, 2))
	var result := tool.use(map, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], available_energy)
	assert_true(result.succeeded())
	assert_equal(result.cells.size(), 3)
	tool.free()
	map.free()


func test_cell_flags_round_trip_and_watered_cleanup() -> void:
	var map := _make_map(2, 1, CellState.CellFlag.DIGGABLE)
	assert_true(map.get_cell(Vector2i.ZERO).apply_tool(ToolMeta.ToolKind.HOE))
	assert_true(map.get_cell(Vector2i.ZERO).apply_tool(ToolMeta.ToolKind.WATERING_CAN))
	var state_dict := map.get_cell(Vector2i.ZERO).state.to_dict()
	var restored_state := CellState.from_dict(state_dict)
	var restored_cell := MapCell.new(Vector2i.ZERO, _state(CellState.CellFlag.DIGGABLE))
	assert_equal(restored_cell.bind_state(restored_state), OK)
	map.cells[Vector2i.ZERO] = restored_cell
	assert_true(map.check_cell(Vector2i.ZERO, CellState.CellCondition.DUG))
	assert_true(map.check_cell(Vector2i.ZERO, CellState.CellCondition.WATERED))
	map._on_day_advanced()
	assert_true(map.check_cell(Vector2i.ZERO, CellState.CellCondition.DUG))
	assert_true(not map.check_cell(Vector2i.ZERO, CellState.CellCondition.WATERED))
	map.free()


func _tool_meta(kind: ToolMeta.ToolKind, energy_cost: int) -> ToolMeta:
	var meta := ToolMeta.new()
	meta.id = &"test_tool"
	meta.tool_kind = kind
	meta.is_cell_tool = kind in [ToolMeta.ToolKind.HOE, ToolMeta.ToolKind.WATERING_CAN]
	meta.base_energy_cost = energy_cost
	return meta


func _test_tool(item_meta: ToolMeta) -> Tool:
	var item_state := ItemState.new()
	item_state.unique_id = &"test_tool"
	item_state.meta_id = item_meta.id
	var tool := Tool.new(item_state)
	tool.meta = item_meta
	return tool


func _make_map(width: int, height: int, flag: CellState.CellFlag) -> BaseMap:
	var map := BaseMap.new()
	for y: int in height:
		for x: int in width:
				map.cells[Vector2i(x, y)] = MapCell.new(Vector2i(x, y), _state(flag))
	return map


func _cell_flags(map: BaseMap) -> Dictionary[Vector2i, int]:
	var result: Dictionary[Vector2i, int] = {}
	for coordinates: Vector2i in map.cells:
		result[coordinates] = map.cells[coordinates].state.flags
	return result


func _state(flags: int) -> CellState:
	var result := CellState.new()
	result.flags = flags
	return result
