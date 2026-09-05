extends ProjectTestCase


func test_new_game_defers_world_generation_until_map_is_loaded() -> void:
	var game_manager := GameManagerService.new()
	assert_equal(game_manager.new_game(99), OK)
	var farm := game_manager.maps[&"farm"] as MapState
	assert_true(not farm.generator_initialized)
	assert_equal(farm.items.size(), 0)
	assert_equal(farm.cells.size(), 0)
	game_manager.free()

func test_new_game_uses_inspector_editable_player_state_template() -> void:
	var game_manager := GameManagerService.new()
	var template := PlayerState.new()
	template.map_id = &"field"
	template.spawn_id = &"entrance"
	template.cell = Vector2i(7, 9)
	template.facing = "left"
	template.max_health = 140
	template.health = 140
	template.max_energy = 175
	template.energy = 175
	template.gold = 725
	var backpack_template := BackpackState.new(4, 2, 3)
	assert_true(backpack_template.set_slot(&"itembar", 1, BackpackSlot.new(&"itembar_1", &"potato_seed", 8)))
	game_manager.config = game_manager.config.duplicate() as GameConfig
	game_manager.config.player_state_template = template
	game_manager.config.backpack_state_template = backpack_template

	assert_equal(game_manager.new_game(321), OK)
	assert_equal(game_manager.player.map_id, &"field")
	assert_equal(game_manager.player.spawn_id, &"entrance")
	assert_equal(game_manager.player.cell, Vector2i(7, 9))
	assert_equal(game_manager.player.facing, &"left")
	assert_equal(game_manager.player.health, 140)
	assert_equal(game_manager.player.max_health, 140)
	assert_equal(game_manager.player.energy, 175)
	assert_equal(game_manager.player.max_energy, 175)
	assert_equal(game_manager.player.gold, 725)
	assert_equal(game_manager.backpack_state.capacity(&"main_space"), 4)
	assert_equal(game_manager.backpack_state.capacity(&"toolbar"), 2)
	assert_equal(game_manager.backpack_state.capacity(&"itembar"), 3)
	assert_equal(game_manager.backpack_state.get_slot(&"itembar", 1).item_id, &"potato_seed")
	assert_equal(game_manager.backpack_state.get_slot(&"itembar", 1).amount, 8)
	assert_equal(game_manager.backpack_state.active_hand_source, BackpackState.ActiveHandSource.NONE)
	game_manager.free()


func test_snapshot_restore_does_not_depend_on_current_player_template() -> void:
	var game_manager := GameManagerService.new()
	assert_equal(game_manager.new_game(322), OK)
	var snapshot := game_manager.snapshot()
	var replacement_template := PlayerState.new()
	game_manager.config = game_manager.config.duplicate() as GameConfig
	game_manager.config.player_state_template = replacement_template
	game_manager.config.backpack_state_template = BackpackState.new(1, 1, 1)

	assert_equal(game_manager.replace_snapshot(snapshot), OK)
	assert_equal(game_manager.backpack_state.capacity(&"main_space"), 18)
	assert_equal(game_manager.backpack_state.capacity(&"toolbar"), 6)
	assert_equal(game_manager.backpack_state.capacity(&"itembar"), 6)
	game_manager.free()


func test_new_game_is_deterministic_and_does_not_accumulate_inventory() -> void:
	var game_manager := GameManagerService.new()
	var connections_before: int = EventBus.inventory_changed.get_connections().size()
	assert_equal(game_manager.new_game(4242), OK)
	var first: Dictionary = game_manager.snapshot()
	assert_equal(game_manager.backpack_state.capacity(&"main_space"), 18)
	assert_equal(game_manager.backpack_state.capacity(&"toolbar"), 6)
	assert_equal(game_manager.backpack_state.capacity(&"itembar"), 6)
	assert_equal(game_manager.backpack_state.count_item(&"itembar", &"parsnip_seed"), 15)
	assert_equal(game_manager.backpack_state.count_item(&"main_space", &"parsnip_seed"), 0)
	for tool_id: StringName in [&"hoe", &"watering_can", &"sickle", &"basket", &"pickaxe", &"axe"]:
		assert_equal(game_manager.backpack_state.count_item(&"toolbar", tool_id), 1)
	assert_equal(game_manager.player.map_id, &"farm")
	assert_equal(game_manager.player.spawn_id, &"default")
	assert_equal(game_manager.new_game(4242), OK)
	assert_equal(game_manager.snapshot(), first)
	assert_equal(EventBus.inventory_changed.get_connections().size(), connections_before)
	game_manager.free()


func test_different_seed_changes_only_seed_in_initial_snapshot() -> void:
	var game_manager := GameManagerService.new()
	assert_equal(game_manager.new_game(100), OK)
	var first: Dictionary = game_manager.snapshot()
	assert_equal(game_manager.new_game(200), OK)
	var second: Dictionary = game_manager.snapshot()
	assert_true(first != second)
	first["world_seed"] = 200
	assert_equal(first, second)
	game_manager.free()


func test_snapshot_is_deep_copy_and_replace_is_atomic() -> void:
	var game_manager := GameManagerService.new()
	assert_equal(game_manager.new_game(77), OK)
	var snapshot: Dictionary = game_manager.snapshot()
	var player_data: Dictionary = snapshot["player"]
	player_data["gold"] = 999999
	var backpack_data: Dictionary = snapshot["backpack"]
	var slots: Dictionary = backpack_data["slots"]
	var first_slot: Dictionary = slots["toolbar_0"]
	first_slot["amount"] = 99
	assert_equal(game_manager.player.gold, 500)
	assert_equal(game_manager.backpack_state.get_slot(&"toolbar", 0).amount, 1)

	var before: Dictionary = game_manager.snapshot()
	var invalid: Dictionary = before.duplicate(true)
	invalid["player"] = {"gold": -1}
	assert_equal(game_manager.replace_snapshot(invalid), ERR_INVALID_DATA)
	assert_equal(game_manager.snapshot(), before)
	game_manager.free()


func test_combined_snapshot_round_trips_game_and_time_state() -> void:
	var game_manager := GameManagerService.new()
	assert_equal(game_manager.new_game(77), OK)
	game_manager.calendar.day = 8
	game_manager.start()
	assert_equal(game_manager.pause(&"inventory"), OK)
	var combined := game_manager.build_snapshot()
	assert_true(combined.has("game"))
	assert_true(combined.has("time"))
	assert_equal(game_manager.new_game(88), OK)
	assert_equal(game_manager.replace_build_snapshot(combined), OK)
	assert_equal(game_manager.calendar.day, 8)
	assert_true(game_manager.is_running())
	assert_true(game_manager.is_paused())
	assert_true(game_manager.pause_reasons().has(&"inventory"))
	game_manager.free()


func test_npcs_are_global_and_keep_their_current_map_location() -> void:
	var game_manager := GameManagerService.new()
	assert_equal(game_manager.new_game(77), OK)
	var npc := NpcState.new()
	npc.npc_id = &"npc_custom"
	npc.schedule_id = &"villager"
	npc.map_id = &"field"
	npc.cell = Vector2i(12, 8)
	npc.current_event_id = &"morning_field"
	assert_equal(game_manager.set_npc(npc), OK)
	assert_equal(game_manager.set_npc(npc), ERR_ALREADY_EXISTS)

	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(game_manager.snapshot())) as Dictionary
	assert_true(not (snapshot["maps"] as Array)[0].has("npcs"))
	assert_equal(game_manager.new_game(77), OK)
	assert_equal(game_manager.npcs.size(), 3)
	assert_equal(game_manager.replace_snapshot(snapshot), OK)
	var restored := game_manager.get_npc(&"npc_custom")
	assert_equal(restored.map_id, &"field")
	assert_equal(restored.cell, Vector2i(12, 8))
	assert_equal(restored.current_event_id, &"morning_field")
	game_manager.free()


func test_replace_snapshot_rejects_invalid_or_duplicate_global_npcs_atomically() -> void:
	var game_manager := GameManagerService.new()
	assert_equal(game_manager.new_game(77), OK)
	var before := game_manager.snapshot()
	var invalid := before.duplicate(true)
	invalid["npcs"] = [_npc_dict("npc_villager", "missing")]
	assert_equal(game_manager.replace_snapshot(invalid), ERR_INVALID_DATA)
	assert_equal(game_manager.snapshot(), before)
	var duplicate := before.duplicate(true)
	duplicate["npcs"] = [_npc_dict("npc_villager", "farm"), _npc_dict("npc_villager", "field")]
	assert_equal(game_manager.replace_snapshot(duplicate), ERR_INVALID_DATA)
	assert_equal(game_manager.snapshot(), before)
	game_manager.free()


func test_reset_and_global_catalog_initialization_are_explicit() -> void:
	var game_manager := GameManagerService.new()
	assert_true(DataCatalog.validate().is_empty())
	assert_equal(game_manager.new_game(1), OK)
	game_manager.reset()
	assert_true(not game_manager.is_initialized())
	assert_equal(game_manager.snapshot(), {})
	game_manager.free()


func test_bar_selection_switches_the_single_active_hand() -> void:
	var game_manager := GameManagerService.new()
	assert_equal(game_manager.new_game(7), OK)
	var backpack := PlayerBackpack.new()
	assert_equal(backpack.setup(game_manager.backpack_state), OK)
	assert_equal(game_manager.backpack_state.active_hand_source, BackpackState.ActiveHandSource.NONE)
	assert_true(backpack.active_slot().is_empty())
	assert_equal(backpack.select_bar_relative(BackpackState.ActiveHandSource.ITEMBAR, 1), OK)
	assert_equal(game_manager.backpack_state.active_hand_source, BackpackState.ActiveHandSource.ITEMBAR)
	assert_equal(backpack.active_slot().item_id, &"pumpkin_seed")
	assert_true(backpack.select_bar_index(BackpackState.ActiveHandSource.ITEMBAR, 0))
	assert_equal(backpack.active_slot().item_id, &"parsnip_seed")
	assert_equal(backpack.select_bar_relative(BackpackState.ActiveHandSource.TOOLBAR, -1), OK)
	assert_equal(game_manager.backpack_state.active_hand_source, BackpackState.ActiveHandSource.TOOLBAR)
	assert_equal(backpack.active_slot().item_id, &"axe")
	backpack.free()
	game_manager.free()


func test_cross_container_exchange_enforces_types_and_merges_atomically() -> void:
	var game_manager := GameManagerService.new()
	assert_equal(game_manager.new_game(7), OK)
	var backpack := PlayerBackpack.new()
	assert_equal(backpack.setup(game_manager.backpack_state), OK)
	var before := game_manager.snapshot()
	assert_equal(backpack.exchange_container_slots(&"toolbar", 0, &"itembar", 1, DataCatalog.get_item(&"hoe"), DataCatalog.get_item(&"parsnip_seed")), ERR_UNAVAILABLE)
	assert_equal(game_manager.snapshot(), before)
	assert_true(game_manager.backpack_state.set_slot(&"main_space", 0, BackpackSlot.new(&"main_space_0", &"parsnip_seed", 10)))
	assert_equal(backpack.exchange_container_slots(&"main_space", 0, &"itembar", 0, DataCatalog.get_item(&"parsnip_seed"), DataCatalog.get_item(&"parsnip_seed")), OK)
	assert_true(game_manager.backpack_state.get_slot(&"main_space", 0).is_empty())
	assert_equal(game_manager.backpack_state.get_slot(&"itembar", 0).amount, 25)
	assert_true(game_manager.backpack_state.set_slot(&"main_space", 1, BackpackSlot.new(&"main_space_1", &"wood", 3)))
	assert_equal(backpack.exchange_container_slots(&"main_space", 1, &"itembar", 3, DataCatalog.get_item(&"wood"), null), OK)
	assert_equal(game_manager.backpack_state.get_slot(&"itembar", 3).item_id, &"wood")
	assert_equal(backpack.exchange_container_slots(&"itembar", 3, &"toolbar", 0, DataCatalog.get_item(&"wood"), DataCatalog.get_item(&"hoe")), ERR_UNAVAILABLE)
	backpack.free()
	game_manager.free()


func test_toolbar_itembar_and_active_hand_round_trip() -> void:
	var game_manager := GameManagerService.new()
	assert_equal(game_manager.new_game(7), OK)
	var backpack := PlayerBackpack.new()
	assert_equal(backpack.setup(game_manager.backpack_state), OK)
	assert_true(backpack.select_bar_index(BackpackState.ActiveHandSource.ITEMBAR, 0))
	game_manager.backpack_state.active_hand_source = BackpackState.ActiveHandSource.ITEMBAR
	var snapshot := JSON.parse_string(JSON.stringify(game_manager.snapshot())) as Dictionary
	assert_equal(game_manager.new_game(8), OK)
	assert_equal(game_manager.replace_snapshot(snapshot), OK)
	assert_equal(game_manager.backpack_state.active_hand_source, BackpackState.ActiveHandSource.ITEMBAR)
	assert_equal(game_manager.backpack_state.count_item(&"toolbar", &"pickaxe"), 1)
	assert_equal(game_manager.backpack_state.count_item(&"itembar", &"parsnip_seed"), 15)
	assert_equal(backpack.active_slot().item_id, &"parsnip_seed")
	backpack.free()
	game_manager.free()


func test_versioned_slot_save_load_is_atomic_and_round_trips_state() -> void:
	var game_manager := GameManagerService.new()
	assert_equal(game_manager.new_game(456), OK)
	game_manager.save_directory = "/tmp/godot_my_farm_t16_slot"
	game_manager.calendar.day = 12
	game_manager.player.gold = 987
	var slot := 91
	var path := game_manager.save_path(slot)
	var backup := path + ".bak"
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(backup)
	assert_equal(game_manager.save_slot(slot), OK)
	assert_true(FileAccess.file_exists(path))
	var envelope := JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary
	assert_equal(envelope.get("schema_version", -1), 1)
	assert_true(envelope.has("saved_at"))
	assert_true((envelope.get("snapshot", {}) as Dictionary).has("game"))
	game_manager.player.gold = 654
	assert_equal(game_manager.save_slot(slot), OK)
	assert_true(FileAccess.file_exists(backup))
	assert_true(not FileAccess.file_exists(path + ".tmp"))
	game_manager.calendar.day = 1
	game_manager.player.gold = 1
	assert_equal(game_manager.load_slot(slot), OK)
	assert_equal(game_manager.calendar.day, 12)
	assert_equal(game_manager.player.gold, 654)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(backup)
	game_manager.free()


func test_invalid_or_future_slot_does_not_replace_current_state() -> void:
	var game_manager := GameManagerService.new()
	assert_equal(game_manager.new_game(789), OK)
	game_manager.save_directory = "/tmp/godot_my_farm_t16_slot_invalid"
	game_manager.player.gold = 432
	var slot := 92
	var path := game_manager.save_path(slot)
	DirAccess.make_dir_recursive_absolute(game_manager.save_directory)
	DirAccess.remove_absolute(path)
	var future := {"schema_version": 99, "saved_at": "test", "snapshot": game_manager.build_snapshot()}
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(future))
	file.close()
	assert_equal(game_manager.load_slot(slot), ERR_INVALID_DATA)
	assert_equal(game_manager.player.gold, 432)
	var corrupt := FileAccess.open(path, FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()
	assert_equal(game_manager.load_slot(slot), ERR_INVALID_DATA)
	assert_equal(game_manager.player.gold, 432)
	DirAccess.remove_absolute(path)
	game_manager.free()


func _npc_dict(npc_id: String, map_id: String) -> Dictionary:
	return {
		"npc_id": npc_id,
		"schedule_id": "villager",
		"map_id": map_id,
		"cell": {"x": 1, "y": 2},
		"facing": "down",
		"behavior_id": "idle",
		"current_event_id": "",
	}
