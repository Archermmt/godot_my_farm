extends ProjectTestCase


func test_target_preview_respects_facing_and_charge_shape() -> void:
	var map := _make_map(12, 12, CellState.CellFlag.DIGGABLE)
	var meta := ToolMeta.new()
	meta.use_kind = ItemMeta.UseKind.GRID_TOOL
	var context := InteractionContext.new(&"farm", Vector2i(5, 5), &"right", 1, &"tool_hoe", 1, 10, map.interaction_revision)
	var cursor := InteractionCursor.new()
	assert_equal(cursor.begin(context, map, meta), OK)
	cursor.update(0.3)
	assert_equal(cursor.preview.size(), 3)
	assert_equal(cursor.preview[0].cell, Vector2i(6, 5))
	assert_equal(cursor.preview[1].cell, Vector2i(7, 5))
	assert_equal(cursor.preview[2].cell, Vector2i(8, 5))
	cursor.free()
	map.free()


func test_seed_preview_is_limited_by_stack_amount_and_map_cells() -> void:
	var map := _make_map(4, 4, CellState.CellFlag.DROPABLE)
	var meta := ToolMeta.new()
	meta.use_kind = ItemMeta.UseKind.SEED
	var context := InteractionContext.new(&"farm", Vector2i(2, 2), &"down", 1, &"seed_parsnip", 2, 10, map.interaction_revision)
	var cursor := InteractionCursor.new()
	assert_equal(cursor.begin(context, map, meta), OK)
	assert_equal(cursor.preview.size(), 1)
	assert_equal(cursor.preview[0].cell, Vector2i(2, 3))
	cursor.free()
	map.free()


func test_preview_uses_transient_cell_state_flags_for_entity_rendering() -> void:
	var map := _make_map(4, 4, CellState.CellFlag.BASE)
	var map_cell := map.get_cell(Vector2i(2, 1))
	assert_equal(map_cell.add_item_id(&"tree_001"), OK)
	var meta := ToolMeta.new()
	meta.use_kind = ItemMeta.UseKind.HARVEST_TOOL
	var context := InteractionContext.new(&"field", Vector2i(1, 1), &"right", 0, &"tool_axe", 1, 10, map.interaction_revision)
	var cursor := InteractionCursor.new()
	assert_equal(cursor.begin(context, map, meta), OK)
	assert_equal(cursor.preview.size(), 1)
	assert_true(cursor.preview[0] != map_cell.cell_state())
	assert_equal(cursor.preview[0].cell, map_cell.cell_state().cell)
	assert_equal(cursor.preview[0].item_ids, [&"tree_001"])
	assert_true((cursor.preview[0].interaction_flags & CellState.InteractionFlag.VALID) != 0)
	assert_true((cursor.preview[0].interaction_flags & CellState.InteractionFlag.ENTITY) != 0)
	assert_equal(map_cell.cell_state().interaction_flags, CellState.InteractionFlag.NONE)
	assert_true(not cursor.preview[0].to_dict().has("interaction_flags"))
	cursor.free()
	map.free()


func test_invalid_map_cell_remains_in_preview_for_cursor_feedback() -> void:
	var map := _make_map(4, 4, CellState.CellFlag.DIGGABLE)
	var map_cell := map.get_cell(Vector2i(2, 1))
	assert_equal(map_cell.add_item_id(&"rock_001"), OK)
	var meta := ToolMeta.new()
	meta.use_kind = ItemMeta.UseKind.GRID_TOOL
	var context := InteractionContext.new(&"farm", Vector2i(1, 1), &"right", 0, &"tool_hoe", 1, 10, map.interaction_revision)
	var cursor := InteractionCursor.new()
	assert_equal(cursor.begin(context, map, meta), OK)
	assert_equal(cursor.preview.size(), 1)
	assert_true((cursor.preview[0].interaction_flags & CellState.InteractionFlag.INVALID) != 0)
	assert_true((cursor.preview[0].interaction_flags & CellState.InteractionFlag.ENTITY) != 0)
	cursor.free()
	map.free()


func test_charge_state_commits_once_and_cancels_on_map_revision_change() -> void:
	var map := _make_map(12, 12, CellState.CellFlag.DIGGABLE)
	var meta := ToolMeta.new()
	meta.use_kind = ItemMeta.UseKind.GRID_TOOL
	var cursor := InteractionCursor.new()
	var context := InteractionContext.new(&"farm", Vector2i(5, 5), &"up", 0, &"tool_hoe", 1, 10, map.interaction_revision)
	assert_equal(cursor.begin(context, map, meta), OK)
	assert_true(cursor.is_charging())
	cursor.update(0.3)
	assert_equal(cursor.charge_level, 1)
	assert_equal(cursor.move_origin(Vector2i(6, 5)), OK)
	assert_equal(cursor.context.facing, &"up")
	assert_equal(cursor.preview[0].cell, Vector2i(6, 4))
	assert_equal(cursor.move_origin(Vector2i(20, 20)), ERR_INVALID_PARAMETER)
	assert_equal(cursor.context.player_cell, Vector2i(6, 5))
	assert_equal(cursor.release(), OK)
	assert_true(not cursor.is_charging())
	assert_equal(cursor.release(), ERR_UNAVAILABLE)

	assert_equal(cursor.begin(context, map, meta), OK)
	map.interaction_revision += 1
	assert_equal(cursor.release(), ERR_INVALID_DATA)
	assert_true(not cursor.is_charging())
	cursor.free()
	map.free()


func _make_map(width: int, height: int, flag: CellState.CellFlag) -> BaseMap:
	var map := BaseMap.new()
	for y: int in height:
		for x: int in width:
			map.cells[Vector2i(x, y)] = MapCell.new(Vector2i(x, y), flag)
	return map
