extends ProjectTestCase

const MAP_PATHS := {
	&"farm": "res://scenes/maps/farm/farm.tscn",
	&"field": "res://scenes/maps/field/field.tscn",
	&"beach": "res://scenes/maps/beach/beach.tscn",
}


func test_all_maps_have_valid_authored_layers() -> void:
	for map_id: StringName in MAP_PATHS:
		var map := (load(MAP_PATHS[map_id]) as PackedScene).instantiate() as BaseMap
		assert_true(map != null)
		assert_equal(map.map_id, map_id)
		assert_equal(map.validate_alignment(), OK)
		assert_true(map.get_map_size().x > 0 and map.get_map_size().y > 0)
		map.free()


func test_map_state_round_trip_uses_sparse_cells_and_items() -> void:
	var map := (load(MAP_PATHS[&"farm"]) as PackedScene).instantiate() as BaseMap
	(Engine.get_main_loop() as SceneTree).root.add_child(map)
	var state := MapState.new()
	state.map_id = &"farm"
	assert_equal(map.from_state(state), OK)
	var cell := map.get_cell(Vector2i(8, 10))
	assert_true(cell != null)
	cell.add_flag(CellState.CellFlag.DUG)
	var saved := map.to_state()
	assert_true(saved.cells.has(Vector2i(8, 10)))
	var restored := MapState.from_dict(saved.to_dict())
	assert_true(restored != null)
	assert_true(restored.cells.has(Vector2i(8, 10)))
	map.free()


func test_runtime_player_and_backpack_are_initialized() -> void:
	assert_true(GameManager.player != null)
	assert_true(GameManager.player.backpack != null)
	assert_true(GameManager.snapshot().has("item_manager"))


func test_successful_tool_use_reports_and_consumes_energy() -> void:
	var player := GameManager.player
	assert_true(player != null)
	var cost := (DataCatalog.get_item(&"hoe") as ToolMeta).level_energy_cost(0)
	assert_true(cost > 0)
	var previous_energy := player.energy
	assert_true(player.consume_energy(cost))
	assert_equal(player.energy, previous_energy - cost)
	player.energy = previous_energy


func test_map_transition_reuses_hosts_without_duplicate_runtime_maps() -> void:
	var initial := MapManager.current_map()
	assert_true(initial != null)
	var field_result := await MapManager._change_map(&"field", &"default", false)
	assert_equal(field_result, OK)
	assert_equal(MapManager.current_map_id(), &"field")
	assert_equal(await MapManager._change_map(&"farm", &"default", false), OK)
	await (Engine.get_main_loop() as SceneTree).process_frame
	assert_equal(MapManager.current_map_id(), &"farm")
	assert_true((MapManager.current_map().get_parent() as Node).get_child_count() <= 2)


func test_save_and_load_round_trip_restores_player_and_manager_state() -> void:
	var previous_directory := GameManager.save_directory
	GameManager.save_directory = "user://t17_integration"
	var previous_gold := GameManager.player.gold
	GameManager.player.gold = previous_gold + 37
	assert_equal(await GameManager.save_game(0), OK)
	await (Engine.get_main_loop() as SceneTree).process_frame
	GameManager.player.gold = 1
	var load_result := await GameManager.load_game(0)
	assert_equal(load_result, OK)
	assert_equal(GameManager.player.gold, previous_gold + 37)
	assert_equal(await GameManager.load_game(0), OK)
	assert_equal(GameManager.player.gold, previous_gold + 37)
	GameManager.player.gold = previous_gold
	var corrupt_path := GameManager.save_path(1)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://t17_integration"))
	var corrupt_file := FileAccess.open(corrupt_path, FileAccess.WRITE)
	corrupt_file.store_string("{broken")
	corrupt_file.close()
	assert_equal(await GameManager.load_game(1), ERR_INVALID_DATA)
	assert_equal(GameManager.player.gold, previous_gold)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(corrupt_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://t17_integration/slot_0.json"))
	GameManager.save_directory = previous_directory


func test_invalid_map_requests_do_not_leave_transition_locks() -> void:
	var before := MapManager.current_map_id()
	GameManager.player._lock_reasons.clear()
	CalendarManager.stop()
	CalendarManager.start()
	assert_equal(MapManager.request_map_change(&"missing_map", &"default"), ERR_DOES_NOT_EXIST)
	assert_equal(MapManager.current_map_id(), before)
	assert_true(not MapManager.is_transitioning())
	assert_true(not CalendarManager.is_paused())
	assert_true(GameManager.player.input_lock_reasons().is_empty())


func test_player_tool_flow_completes_hoe_seed_and_water_actions() -> void:
	var map := MapManager.current_map()
	var player := GameManager.player
	assert_true(map != null and player != null and player.backpack != null)
	var target := Vector2i(-1, -1)
	var origin := Vector2i(-1, -1)
	for candidate: Vector2i in map.map_layers[CellState.CellFlag.BASE].get_used_cells():
		var candidate_origin := candidate + Vector2i.LEFT
		if (
			map.check_cell(candidate, CellState.CellCondition.DIGGABLE)
			and map.check_cell(candidate_origin, CellState.CellCondition.WALKABLE)
		):
			target = candidate
			origin = candidate_origin
			break
	assert_true(target != Vector2i(-1, -1), "farm needs a clear diggable cell for keyboard flow")
	if target == Vector2i(-1, -1):
		return
	var original_position := player.global_position
	var original_facing := player.facing
	var original_energy := player.energy
	var original_active_source := player.backpack.active_hand_source
	var original_toolbar_selection: StringName = player.backpack.selected_ids.get(&"toolbar", &"")
	var original_itembar_selection: StringName = player.backpack.selected_ids.get(&"itembar", &"")
	var original_item_manager := ItemManager.to_dict()
	var target_cell := map.ensure_cell(target)
	var original_flags := target_cell.state.flags
	var original_item_ids := target_cell.state.item_ids.duplicate()
	player.global_position = map.cell_to_world(origin)
	player.facing = &"right"
	assert_true(player.backpack.select_bar_index(PlayerBackpack.ActiveHandSource.TOOLBAR, 0))
	assert_true(player.backpack.active_slot() != null)
	assert_equal(player.backpack.active_slot().item_id if player.backpack.active_slot() != null else &"", &"hoe")
	player._begin_hold()
	player._use_tool()
	assert_true(map.check_cell(target, CellState.CellCondition.DUG), "hoe must dig the target cell")

	var seed_count := player.backpack.count_item(&"itembar", &"parsnip_seed")
	assert_true(player.backpack.select_bar_index(PlayerBackpack.ActiveHandSource.ITEMBAR, 0))
	assert_equal(player.backpack.active_slot().item_id if player.backpack.active_slot() != null else &"", &"parsnip_seed")
	player._begin_hold()
	player._use_tool()
	assert_equal(player.backpack.count_item(&"itembar", &"parsnip_seed"), seed_count - 1)
	assert_true(target_cell.state.item_ids.size() > original_item_ids.size(), "seed must bind a plant to the target cell")

	assert_true(player.backpack.select_bar_index(PlayerBackpack.ActiveHandSource.TOOLBAR, 1))
	assert_equal(player.backpack.active_slot().item_id if player.backpack.active_slot() != null else &"", &"watering_can")
	player._begin_hold()
	player._use_tool()
	assert_true(map.check_cell(target, CellState.CellCondition.WATERED), "watering can must water a planted dug cell")

	for item_id: StringName in target_cell.state.item_ids.duplicate():
		if item_id not in original_item_ids:
			map.remove_item(item_id)
	target_cell.state.flags = original_flags
	var seed_slot := player.backpack.get_slot(&"itembar", 0)
	if seed_slot != null:
		seed_slot.amount = seed_count
	player.global_position = original_position
	player.facing = original_facing
	player.energy = original_energy
	player.backpack.selected_ids[&"toolbar"] = original_toolbar_selection
	player.backpack.selected_ids[&"itembar"] = original_itembar_selection
	player.backpack.active_hand_source = original_active_source
	ItemManager.from_dict(original_item_manager)


func test_one_hundred_invalid_actions_do_not_change_snapshot() -> void:
	var player := GameManager.player
	var before := GameManager.snapshot()
	for _index: int in 100:
		player._cancel_hold()
		player._drop_item()
		player._interact_with_facing_target()
	assert_equal(GameManager.snapshot(), before)


func test_transition_and_save_stress_does_not_duplicate_map_hosts() -> void:
	var previous_directory := GameManager.save_directory
	GameManager.save_directory = "user://t17_stress"
	for _index: int in 20:
		assert_equal(await MapManager._change_map(&"field", &"default", false), OK)
		assert_equal(await MapManager._change_map(&"farm", &"default", false), OK)
	for _index: int in 10:
		assert_equal(await GameManager.save_game(0), OK)
	assert_true((MapManager.current_map().get_parent() as Node).get_child_count() <= 2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://t17_stress/slot_0.json"))
	GameManager.save_directory = previous_directory


func test_one_hundred_dynamic_items_can_be_added_and_removed() -> void:
	var map := MapManager.current_map()
	assert_true(map != null)
	var created: Array[StringName] = []
	var coordinates := map.map_layers[CellState.CellFlag.BASE].get_used_cells()
	for cell: Vector2i in coordinates:
		if created.size() >= 100:
			break
		if not map.check_cell(cell, CellState.CellCondition.DROPABLE):
			continue
		var item := ItemManager.create_from_id(&"wood")
		if item == null or map.add_item(item, map.cell_to_world(cell, false)) != OK:
			if item != null:
				item.free()
			continue
		created.append(item.item_id())
	assert_equal(created.size(), 100)
	for item_id: StringName in created:
		assert_equal(map.remove_item(item_id), OK)
	assert_true(created.all(func(item_id: StringName) -> bool: return map.get_item(item_id) == null))


func test_two_day_transitions_advance_calendar_once_each() -> void:
	var old_day := CalendarManager.day
	var old_month := CalendarManager.month
	var old_hour := CalendarManager.hour
	var old_minute := CalendarManager.minute
	var first_day := old_day
	assert_equal(CalendarManager.next_day(), OK)
	for _frame: int in 80:
		await (Engine.get_main_loop() as SceneTree).process_frame
	first_day = CalendarManager.day
	assert_true(first_day != old_day or CalendarManager.month != old_month)
	assert_equal(CalendarManager.next_day(), OK)
	for _frame: int in 80:
		await (Engine.get_main_loop() as SceneTree).process_frame
	assert_true(CalendarManager.day != first_day or CalendarManager.month != old_month)
	CalendarManager.day = old_day
	CalendarManager.month = old_month
	CalendarManager.hour = old_hour
	CalendarManager.minute = old_minute
