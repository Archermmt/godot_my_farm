extends ProjectTestCase


func test_target_preview_respects_facing_and_charge_shape() -> void:
	var map := _make_map(12, 12, CellState.CellFlag.DIGGABLE)
	var meta := ToolMeta.new()
	meta.tool_kind = ToolMeta.ToolKind.HOE
	var tool := Tool.new(meta)
	var player_state := _player_state(Vector2i(5, 5), &"right", &"hoe", 1, 10)
	var cursor := EffectArea.new()
	assert_equal(cursor.begin(player_state, map, tool), OK)
	cursor.update(0.3)
	assert_equal(cursor.preview.size(), 3)
	assert_equal(cursor.preview[0].cell, Vector2i(6, 5))
	assert_equal(cursor.preview[1].cell, Vector2i(7, 5))
	assert_equal(cursor.preview[2].cell, Vector2i(8, 5))
	tool.free()
	cursor.free()
	map.free()


func test_pickaxe_and_axe_charge_damage_without_expanding_preview() -> void:
	for tool_id: StringName in [&"pickaxe", &"axe"]:
		var meta := DataCatalog.get_item(tool_id) as ToolMeta
		assert_equal(meta.charge_levels, [Vector2i(1, 1)])
		assert_equal(meta.damage_multipliers, [1, 2, 3])
		assert_true(meta.charges_damage())
		var map := _make_map(20, 20, CellState.CellFlag.BASE)
		var player_state := _player_state(Vector2i(10, 10), &"right", tool_id, 1, 10)
		var cursor := EffectArea.new()
		var tool := Tool.new(meta)
		assert_equal(cursor.begin(player_state, map, tool), OK)
		cursor.update(10.0)
		assert_equal(cursor.charge_level, 2)
		assert_equal(cursor.preview.size(), 1)
		assert_equal(cursor.preview[0].cell, Vector2i(11, 10))
		assert_equal(cursor.charge_progress(), 1.0)
		tool.free()
		cursor.free()
		map.free()


func test_other_tools_keep_five_charge_levels() -> void:
	for tool_id: StringName in [&"hoe", &"watering_can", &"sickle", &"basket"]:
		var meta := DataCatalog.get_item(tool_id) as ToolMeta
		assert_equal(meta.charge_levels, [Vector2i(1, 1), Vector2i(3, 1), Vector2i(3, 3), Vector2i(9, 3), Vector2i(9, 9)])
		assert_equal(meta.max_charge_level(), 4)
	for tool_id: StringName in [&"pickaxe", &"axe"]:
		assert_equal((DataCatalog.get_item(tool_id) as ToolMeta).max_charge_level(), 2)


func test_tool_meta_defines_charge_levels_and_progress() -> void:
	var map := _make_map(12, 12, CellState.CellFlag.DIGGABLE)
	var player_state := _player_state(Vector2i(5, 5), &"right", &"hoe", 1, 10)
	var meta := DataCatalog.get_item(&"hoe") as ToolMeta
	var tool := Tool.new(meta)
	var cursor := EffectArea.new()
	assert_equal(cursor.begin(player_state, map, tool), OK)
	cursor.update(10.0)
	assert_equal(cursor.charge_level, 4)
	assert_equal(cursor.preview.size(), 54)
	assert_equal(cursor.charge_progress(), 1.0)
	tool.free()
	cursor.free()
	map.free()


func test_seed_preview_is_limited_by_stack_amount_and_map_cells() -> void:
	var map := _make_map(8, 8, CellState.CellFlag.DROPABLE, CellState.CellFlag.DUG)
	var meta := DataCatalog.get_seed(&"parsnip_seed")
	assert_equal(meta.charge_levels, [Vector2i(1, 1), Vector2i(3, 1), Vector2i(3, 3), Vector2i(9, 3)])
	var player_state := _player_state(Vector2i(2, 2), &"down", &"parsnip_seed", 2, 10)
	var cursor := EffectArea.new()
	var seed := Seed.new(meta)
	assert_equal(cursor.begin(player_state, map, seed), OK)
	assert_equal(cursor.preview.size(), 1)
	assert_equal(cursor.preview[0].cell, Vector2i(2, 3))
	cursor.update(0.3)
	assert_equal(cursor.preview.size(), 3)
	assert_true((cursor.preview[0].interaction_flags & CellState.InteractionFlag.VALID) != 0)
	assert_true((cursor.preview[1].interaction_flags & CellState.InteractionFlag.VALID) != 0)
	assert_true((cursor.preview[2].interaction_flags & CellState.InteractionFlag.INVALID) != 0)
	player_state.backpack_state.set_slot(&"toolbar", 0, BackpackSlot.new(&"toolbar_0", &"parsnip_seed", 1))
	cursor.cancel()
	cursor.begin(player_state, map, seed)
	cursor.update(1.0)
	assert_true(cursor.preview.size() > 1)
	assert_true((cursor.preview[1].interaction_flags & CellState.InteractionFlag.INVALID) != 0)
	seed.free()
	cursor.free()
	map.free()


func test_seed_stops_at_four_charge_levels_and_reaches_nine_by_three() -> void:
	for seed_id: StringName in [&"parsnip_seed", &"pumpkin_seed", &"potato_seed"]:
		var meta := DataCatalog.get_seed(seed_id)
		assert_equal(meta.charge_levels, [Vector2i(1, 1), Vector2i(3, 1), Vector2i(3, 3), Vector2i(9, 3)])
		var map := _make_map(24, 24, CellState.CellFlag.DROPABLE, CellState.CellFlag.DUG)
		var player_state := _player_state(Vector2i(7, 10), &"right", seed_id, 99, 10)
		var cursor := EffectArea.new()
		var seed := Seed.new(meta)
		assert_equal(cursor.begin(player_state, map, seed), OK)
		cursor.update(10.0)
		assert_equal(cursor.charge_level, 3)
		assert_equal(cursor.preview.size(), 27)
		seed.free()
		cursor.free()
		map.free()


func test_player_backpack_reuses_tool_and_seed_objects_until_stack_disappears() -> void:
	var backpack := PlayerBackpack.new()
	var player_state := PlayerState.new()
	player_state.backpack_state.set_slot(&"toolbar", 0, BackpackSlot.new(&"toolbar_0", &"hoe", 1))
	player_state.backpack_state.set_slot(&"itembar", 0, BackpackSlot.new(&"itembar_0", &"parsnip_seed", 2))
	player_state.active_hand_source = PlayerState.ActiveHandSource.TOOLBAR
	backpack.sync_from_player_state(player_state)
	var hoe := backpack.active_item(player_state)
	assert_true(hoe is Tool)
	assert_true(backpack.active_item(player_state) == hoe)
	player_state.active_hand_source = PlayerState.ActiveHandSource.ITEMBAR
	var seed := backpack.active_item(player_state)
	assert_true(seed is Seed)
	assert_true(backpack.active_item(player_state) == seed)
	assert_equal(backpack.get_child_count(), 2)
	player_state.backpack_state.remove_item(&"itembar", &"parsnip_seed", 2)
	backpack.sync_from_player_state(player_state)
	assert_true(seed.is_queued_for_deletion())
	assert_true(not hoe.is_queued_for_deletion())
	backpack.free()


func test_preview_uses_transient_cell_state_flags_for_entity_rendering() -> void:
	var map := _make_map(4, 4, CellState.CellFlag.BASE)
	var map_cell := map.get_cell(Vector2i(2, 1))
	assert_equal(map_cell.add_item_id(&"tree_001"), OK)
	var meta := ToolMeta.new()
	meta.tool_kind = ToolMeta.ToolKind.NONE
	var tool := Tool.new(meta)
	var player_state := _player_state(Vector2i(1, 1), &"right", &"axe", 1, 10)
	var cursor := EffectArea.new()
	assert_equal(cursor.begin(player_state, map, tool), OK)
	assert_equal(cursor.preview.size(), 1)
	assert_true(cursor.preview[0] != map_cell.cell_state())
	assert_equal(cursor.preview[0].cell, map_cell.cell_state().cell)
	assert_equal(cursor.preview[0].item_ids, [&"tree_001"])
	assert_true((cursor.preview[0].interaction_flags & CellState.InteractionFlag.VALID) != 0)
	assert_true((cursor.preview[0].interaction_flags & CellState.InteractionFlag.ENTITY) != 0)
	assert_equal(map_cell.cell_state().interaction_flags, CellState.InteractionFlag.NONE)
	assert_true(not cursor.preview[0].to_dict().has("interaction_flags"))
	tool.free()
	cursor.free()
	map.free()


func test_invalid_map_cell_remains_in_preview_for_cursor_feedback() -> void:
	var map := _make_map(4, 4, CellState.CellFlag.DIGGABLE)
	var map_cell := map.get_cell(Vector2i(2, 1))
	assert_equal(map_cell.add_item_id(&"rock_001"), OK)
	var meta := ToolMeta.new()
	meta.tool_kind = ToolMeta.ToolKind.HOE
	var tool := Tool.new(meta)
	var player_state := _player_state(Vector2i(1, 1), &"right", &"hoe", 1, 10)
	var cursor := EffectArea.new()
	assert_equal(cursor.begin(player_state, map, tool), OK)
	assert_equal(cursor.preview.size(), 1)
	assert_true((cursor.preview[0].interaction_flags & CellState.InteractionFlag.INVALID) != 0)
	assert_true((cursor.preview[0].interaction_flags & CellState.InteractionFlag.ENTITY) != 0)
	tool.free()
	cursor.free()
	map.free()


func test_charge_state_commits_once_and_cancels_on_map_revision_change() -> void:
	var map := _make_map(12, 12, CellState.CellFlag.DIGGABLE)
	var meta := ToolMeta.new()
	meta.tool_kind = ToolMeta.ToolKind.HOE
	var tool := Tool.new(meta)
	var cursor := EffectArea.new()
	var player_state := _player_state(Vector2i(5, 5), &"up", &"hoe", 1, 10)
	assert_equal(cursor.begin(player_state, map, tool), OK)
	assert_true(cursor.is_charging())
	cursor.update(0.3)
	assert_equal(cursor.charge_level, 1)
	assert_equal(cursor.move_origin(Vector2i(6, 5)), OK)
	assert_equal(player_state.facing, &"up")
	assert_equal(cursor.preview[0].cell, Vector2i(6, 4))
	assert_equal(cursor.move_origin(Vector2i(20, 20)), ERR_INVALID_PARAMETER)
	assert_equal(player_state.cell, Vector2i(6, 5))
	assert_equal(cursor.release_preview(), OK)
	assert_true(not cursor.is_charging())
	assert_equal(cursor.release_preview(), ERR_UNAVAILABLE)

	player_state.cell = Vector2i(5, 5)
	assert_equal(cursor.begin(player_state, map, tool), OK)
	map.interaction_revision += 1
	assert_equal(cursor.release_preview(), ERR_INVALID_DATA)
	assert_true(not cursor.is_charging())
	tool.free()
	cursor.free()
	map.free()


func test_cursor_release_returns_preview_cells_for_player_owned_transactions() -> void:
	var map := _make_map(4, 4, CellState.CellFlag.DIGGABLE)
	var player_state := _player_state(Vector2i(1, 1), &"right", &"hoe", 1, 5)
	var cursor := EffectArea.new()
	var hoe := ToolMeta.new()
	hoe.tool_kind = ToolMeta.ToolKind.HOE
	hoe.base_stamina_cost = 2
	var hoe_tool := Tool.new(hoe)
	assert_equal(cursor.begin(player_state, map, hoe_tool), OK)
	var target_cells := cursor.preview_cells()
	assert_equal(cursor.release_preview(), OK)
	assert_equal(target_cells, [Vector2i(2, 1)])
	var hoe_result := hoe_tool.use(map, target_cells, player_state.stamina)
	assert_true(hoe_result.succeeded())
	player_state.set_stamina(player_state.stamina - hoe_result.stamina_spent)
	assert_true(map.get_cell(Vector2i(2, 1)).is_dug())
	assert_equal(player_state.stamina, 3)

	var watering_can := ToolMeta.new()
	watering_can.tool_kind = ToolMeta.ToolKind.WATERING_CAN
	watering_can.base_stamina_cost = 1
	var watering_tool := Tool.new(watering_can)
	player_state.cell = Vector2i(1, 1)
	player_state.backpack_state.set_slot(&"toolbar", 0, BackpackSlot.new(&"toolbar_0", &"watering_can", 1))
	player_state.set_stamina(3)
	assert_equal(cursor.begin(player_state, map, watering_tool), OK)
	target_cells = cursor.preview_cells()
	assert_equal(cursor.release_preview(), OK)
	var water_result := watering_tool.use(map, target_cells, player_state.stamina)
	player_state.set_stamina(player_state.stamina - water_result.stamina_spent)
	assert_true(map.get_cell(Vector2i(2, 1)).is_watered())
	assert_equal(player_state.stamina, 2)
	hoe_tool.free()
	watering_tool.free()
	cursor.free()
	map.free()


func _make_map(width: int, height: int, meta_flags: int, state_flags: int = 0) -> BaseMap:
	var map := BaseMap.new()
	for y: int in height:
		for x: int in width:
			var cell := MapCell.new(Vector2i(x, y), meta_flags)
			cell.set_state_flags(state_flags)
			map.cells[Vector2i(x, y)] = cell
	return map


func _player_state(cell: Vector2i, facing: StringName, item_id: StringName, amount: int, stamina: int) -> PlayerState:
	var player_state := PlayerState.new()
	player_state.cell = cell
	player_state.facing = facing
	player_state.set_stamina(stamina)
	player_state.backpack_state.set_slot(&"toolbar", 0, BackpackSlot.new(&"toolbar_0", item_id, amount))
	player_state.active_hand_source = PlayerState.ActiveHandSource.TOOLBAR
	return player_state
