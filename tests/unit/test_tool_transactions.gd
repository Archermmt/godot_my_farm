extends ProjectTestCase


func test_hoe_changes_only_valid_cells_and_reports_skips() -> void:
	var map := _make_map(4, 2, CellState.CellFlag.DIGGABLE)
	map.get_cell(Vector2i(1, 0)).add_item_id(&"rock")
	map.get_cell(Vector2i(2, 0)).static_flags = CellState.CellFlag.BASE
	var player := PlayerState.new()
	player.set_stamina(20)
	var tool := Tool.new(_tool_meta(ToolMeta.ToolKind.HOE, 2))
	var result := tool.use(map, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], player.stamina)
	assert_true(result.succeeded())
	assert_equal(result.effect_cells, [Vector2i(0, 0)])
	assert_equal(result.skipped_reasons[Vector2i(1, 0)], &"occupied")
	assert_equal(result.skipped_reasons[Vector2i(2, 0)], &"not_diggable")
	assert_equal(result.stamina_spent, 2)
	assert_equal(player.stamina, 20)
	assert_true(map.get_cell(Vector2i(0, 0)).is_dug())
	assert_equal(map.interaction_revision, 1)
	tool.free()
	map.free()


func test_water_rejects_untilled_and_repeated_cells_without_spending_stamina() -> void:
	var map := _make_map(3, 1, CellState.CellFlag.DIGGABLE)
	assert_equal(map.get_cell(Vector2i(0, 0)).use_tool(ToolMeta.ToolKind.HOE), OK)
	assert_equal(map.get_cell(Vector2i(1, 0)).use_tool(ToolMeta.ToolKind.HOE), OK)
	assert_equal(map.get_cell(Vector2i(1, 0)).use_tool(ToolMeta.ToolKind.WATERING_CAN), OK)
	var player := PlayerState.new()
	player.set_stamina(10)
	var tool := Tool.new(_tool_meta(ToolMeta.ToolKind.WATERING_CAN, 1))
	var result := tool.use(map, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], player.stamina)
	assert_true(result.succeeded())
	assert_equal(result.effect_cells, [Vector2i(0, 0)])
	assert_equal(result.skipped_reasons[Vector2i(1, 0)], &"already_watered")
	assert_equal(result.skipped_reasons[Vector2i(2, 0)], &"not_dug")
	assert_equal(player.stamina, 10)
	var repeated := tool.use(map, [Vector2i(0, 0)], player.stamina)
	assert_equal(repeated.error, ERR_UNAVAILABLE)
	assert_equal(repeated.stamina_spent, 0)
	assert_equal(player.stamina, 10)
	tool.free()
	map.free()


func test_multi_cell_tool_use_is_atomic_at_stamina_boundaries() -> void:
	for starting_stamina: int in [0, 1, 2]:
		var map := _make_map(2, 1, CellState.CellFlag.DIGGABLE)
		var player := PlayerState.new()
		player.set_stamina(starting_stamina)
		var before := _cell_flags(map)
		var result := Tool.perform(
			_tool_meta(ToolMeta.ToolKind.HOE, 2),
			map,
			[Vector2i(0, 0), Vector2i(1, 0)],
			player.stamina
		)
		if starting_stamina < 2:
			assert_equal(result.error, ERR_CANT_ACQUIRE_RESOURCE)
			assert_equal(_cell_flags(map), before)
			assert_equal(player.stamina, starting_stamina)
			assert_equal(map.interaction_revision, 0)
		else:
			assert_true(result.succeeded())
			assert_equal(result.effect_cells.size(), 2)
			assert_equal(player.stamina, starting_stamina)
			assert_equal(map.interaction_revision, 1)
		map.free()


func test_max_charge_hoe_changes_nine_by_nine_for_one_use_cost() -> void:
	var map := _make_map(9, 9, CellState.CellFlag.DIGGABLE)
	var player := PlayerState.new()
	player.set_stamina(100)
	var targets: Array[Vector2i] = []
	for y: int in 9:
		for x: int in 9:
			targets.append(Vector2i(x, y))
	var result := Tool.perform(_tool_meta(ToolMeta.ToolKind.HOE, 2), map, targets, player.stamina)
	assert_true(result.succeeded())
	assert_equal(result.effect_cells.size(), 81)
	assert_equal(result.stamina_spent, 2)
	assert_equal(player.stamina, 100)
	assert_equal(map.interaction_revision, 1)
	map.free()


func test_tool_result_reports_one_successful_batch() -> void:
	var map := _make_map(3, 1, CellState.CellFlag.DIGGABLE)
	var available_stamina := 10
	var result := Tool.perform(
		_tool_meta(ToolMeta.ToolKind.HOE, 2),
		map,
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
		available_stamina
	)
	assert_true(result.succeeded())
	assert_equal(result.tool_kind, ToolMeta.ToolKind.HOE)
	assert_equal(result.effect_cells.size(), 3)
	assert_equal(result.stamina_spent, 2)
	map.free()


func test_cell_flags_round_trip_and_watered_cleanup() -> void:
	var map := _make_map(2, 1, CellState.CellFlag.DIGGABLE)
	assert_equal(map.get_cell(Vector2i.ZERO).use_tool(ToolMeta.ToolKind.HOE), OK)
	assert_equal(map.get_cell(Vector2i.ZERO).use_tool(ToolMeta.ToolKind.WATERING_CAN), OK)
	var state_dict := map.get_cell(Vector2i.ZERO).cell_state().to_dict()
	var restored_state := CellState.from_dict(state_dict)
	var restored_cell := MapCell.new(Vector2i.ZERO, CellState.CellFlag.DIGGABLE)
	assert_equal(restored_cell.bind_state(restored_state), OK)
	assert_true(restored_cell.is_dug())
	assert_true(restored_cell.is_watered())
	assert_equal(map.clear_watered(), [Vector2i.ZERO])
	assert_true(map.get_cell(Vector2i.ZERO).is_dug())
	assert_true(not map.get_cell(Vector2i.ZERO).is_watered())
	map.free()


func _tool_meta(kind: ToolMeta.ToolKind, stamina_cost: int) -> ToolMeta:
	var meta := ToolMeta.new()
	meta.id = &"test_tool"
	meta.tool_kind = kind
	meta.base_stamina_cost = stamina_cost
	return meta


func _make_map(width: int, height: int, flag: CellState.CellFlag) -> BaseMap:
	var map := BaseMap.new()
	for y: int in height:
		for x: int in width:
			map.cells[Vector2i(x, y)] = MapCell.new(Vector2i(x, y), flag)
	return map


func _cell_flags(map: BaseMap) -> Dictionary[Vector2i, int]:
	var result: Dictionary[Vector2i, int] = {}
	for coordinates: Vector2i in map.cells:
		result[coordinates] = map.cells[coordinates].state_flags()
	return result
