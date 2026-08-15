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
	template.max_stamina = 175
	template.stamina = 175
	template.gold = 725
	template.backpack_state = BackpackState.new(4, 2, 3)
	assert_true(template.backpack_state.set_slot(&"itembar", 1, BackpackSlot.new(&"itembar_1", &"seed_potato", 8)))
	game_manager.player_state_template = template

	assert_equal(game_manager.new_game(321), OK)
	assert_equal(game_manager.player.map_id, &"field")
	assert_equal(game_manager.player.spawn_id, &"entrance")
	assert_equal(game_manager.player.cell, Vector2i(7, 9))
	assert_equal(game_manager.player.facing, &"left")
	assert_equal(game_manager.player.health, 140)
	assert_equal(game_manager.player.max_health, 140)
	assert_equal(game_manager.player.stamina, 175)
	assert_equal(game_manager.player.max_stamina, 175)
	assert_equal(game_manager.player.gold, 725)
	assert_equal(game_manager.player.backpack_state.capacity(&"inventory"), 4)
	assert_equal(game_manager.player.backpack_state.capacity(&"toolbar"), 2)
	assert_equal(game_manager.player.backpack_state.capacity(&"itembar"), 3)
	assert_equal(game_manager.player.backpack_state.get_slot(&"itembar", 1).item_id, &"seed_potato")
	assert_equal(game_manager.player.backpack_state.get_slot(&"itembar", 1).amount, 8)
	assert_equal(game_manager.player.active_hand_source, PlayerState.ActiveHandSource.NONE)
	game_manager.free()


func test_snapshot_restore_does_not_depend_on_current_player_template() -> void:
	var game_manager := GameManagerService.new()
	assert_equal(game_manager.new_game(322), OK)
	var snapshot := game_manager.snapshot()
	var replacement_template := PlayerState.new()
	replacement_template.backpack_state = BackpackState.new(1, 1, 1)
	game_manager.player_state_template = replacement_template

	assert_equal(game_manager.replace_snapshot(snapshot), OK)
	assert_equal(game_manager.player.backpack_state.capacity(&"inventory"), 20)
	assert_equal(game_manager.player.backpack_state.capacity(&"toolbar"), 6)
	assert_equal(game_manager.player.backpack_state.capacity(&"itembar"), 10)
	game_manager.free()


func test_new_game_is_deterministic_and_does_not_accumulate_inventory() -> void:
	var game_manager := GameManagerService.new()
	var connections_before: int = EventBus.inventory_changed.get_connections().size()
	assert_equal(game_manager.new_game(4242), OK)
	var first: Dictionary = game_manager.snapshot()
	assert_equal(game_manager.player.backpack_state.capacity(&"inventory"), 20)
	assert_equal(game_manager.player.backpack_state.capacity(&"toolbar"), 6)
	assert_equal(game_manager.player.backpack_state.capacity(&"itembar"), 10)
	assert_equal(game_manager.player.backpack_state.count_item(&"itembar", &"seed_parsnip"), 15)
	assert_equal(game_manager.player.backpack_state.count_item(&"inventory", &"seed_parsnip"), 0)
	for tool_id: StringName in [&"tool_hoe", &"tool_watering_can", &"tool_sickle", &"tool_basket", &"tool_pickaxe", &"tool_axe"]:
		assert_equal(game_manager.player.backpack_state.count_item(&"toolbar", tool_id), 1)
	assert_equal(game_manager.player.map_id, &"cabin")
	assert_equal(game_manager.player.spawn_id, &"wake")
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
	var backpack_data: Dictionary = (snapshot["player"] as Dictionary)["backpack"]
	var slots: Dictionary = backpack_data["slots"]
	var first_slot: Dictionary = slots["toolbar_0"]
	first_slot["amount"] = 99
	assert_equal(game_manager.player.gold, 500)
	assert_equal(game_manager.player.backpack_state.get_slot(&"toolbar", 0).amount, 1)

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
	npc.npc_id = &"npc_villager"
	npc.schedule_id = &"schedule_villager"
	npc.map_id = &"field"
	npc.cell = Vector2i(12, 8)
	npc.current_event_id = &"morning_field"
	assert_equal(game_manager.set_npc(npc), OK)
	assert_equal(game_manager.set_npc(npc), ERR_ALREADY_EXISTS)

	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(game_manager.snapshot())) as Dictionary
	assert_true(not (snapshot["maps"] as Array)[0].has("npcs"))
	assert_equal(game_manager.new_game(77), OK)
	assert_true(game_manager.npcs.is_empty())
	assert_equal(game_manager.replace_snapshot(snapshot), OK)
	var restored := game_manager.get_npc(&"npc_villager")
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
	assert_true(DataCatalog.is_ready_for_game())
	assert_equal(game_manager.new_game(1), OK)
	game_manager.reset()
	assert_true(not game_manager.is_initialized())
	assert_equal(game_manager.snapshot(), {})
	game_manager.free()


func test_bar_selection_switches_the_single_active_hand() -> void:
	var game_manager := GameManagerService.new()
	assert_equal(game_manager.new_game(7), OK)
	assert_equal(game_manager.player.active_hand_source, PlayerState.ActiveHandSource.NONE)
	assert_true(game_manager.player.active_stack().is_empty())
	assert_equal(game_manager.player.select_bar_relative(PlayerState.ActiveHandSource.ITEMBAR, 1), OK)
	assert_equal(game_manager.player.active_hand_source, PlayerState.ActiveHandSource.ITEMBAR)
	assert_equal(game_manager.player.active_stack().item_id, &"seed_pumpkin")
	assert_equal(game_manager.player.select_bar_index(PlayerState.ActiveHandSource.ITEMBAR, 0), OK)
	assert_equal(game_manager.player.active_stack().item_id, &"seed_parsnip")
	assert_equal(game_manager.player.select_bar_relative(PlayerState.ActiveHandSource.TOOLBAR, -1), OK)
	assert_equal(game_manager.player.active_hand_source, PlayerState.ActiveHandSource.TOOLBAR)
	assert_equal(game_manager.player.active_stack().item_id, &"tool_axe")
	game_manager.free()


func test_cross_container_exchange_enforces_types_and_merges_atomically() -> void:
	var game_manager := GameManagerService.new()
	assert_equal(game_manager.new_game(7), OK)
	var before := game_manager.snapshot()
	assert_equal(game_manager.player.exchange_container_slots(&"toolbar", 0, &"itembar", 1, DataCatalog.get_item(&"tool_hoe"), DataCatalog.get_item(&"seed_parsnip")), ERR_UNAVAILABLE)
	assert_equal(game_manager.snapshot(), before)
	assert_true(game_manager.player.backpack_state.set_slot(&"inventory", 0, BackpackSlot.new(&"inventory_0", &"seed_parsnip", 10)))
	assert_equal(game_manager.player.exchange_container_slots(&"inventory", 0, &"itembar", 0, DataCatalog.get_item(&"seed_parsnip"), DataCatalog.get_item(&"seed_parsnip")), OK)
	assert_true(game_manager.player.backpack_state.get_slot(&"inventory", 0).is_empty())
	assert_equal(game_manager.player.backpack_state.get_slot(&"itembar", 0).amount, 25)
	assert_true(game_manager.player.backpack_state.set_slot(&"inventory", 1, BackpackSlot.new(&"inventory_1", &"material_wood", 3)))
	assert_equal(game_manager.player.exchange_container_slots(&"inventory", 1, &"itembar", 3, DataCatalog.get_item(&"material_wood"), null), OK)
	assert_equal(game_manager.player.backpack_state.get_slot(&"itembar", 3).item_id, &"material_wood")
	assert_equal(game_manager.player.exchange_container_slots(&"itembar", 3, &"toolbar", 0, DataCatalog.get_item(&"material_wood"), DataCatalog.get_item(&"tool_hoe")), ERR_UNAVAILABLE)
	game_manager.free()


func test_toolbar_itembar_and_active_hand_round_trip() -> void:
	var game_manager := GameManagerService.new()
	assert_equal(game_manager.new_game(7), OK)
	assert_equal(game_manager.player.select_bar_index(PlayerState.ActiveHandSource.ITEMBAR, 0), OK)
	var snapshot := JSON.parse_string(JSON.stringify(game_manager.snapshot())) as Dictionary
	assert_equal(game_manager.new_game(8), OK)
	assert_equal(game_manager.replace_snapshot(snapshot), OK)
	assert_equal(game_manager.player.active_hand_source, PlayerState.ActiveHandSource.ITEMBAR)
	assert_equal(game_manager.player.backpack_state.count_item(&"toolbar", &"tool_pickaxe"), 1)
	assert_equal(game_manager.player.backpack_state.count_item(&"itembar", &"seed_parsnip"), 15)
	assert_equal(game_manager.player.active_stack().item_id, &"seed_parsnip")
	game_manager.free()


func _npc_dict(npc_id: String, map_id: String) -> Dictionary:
	return {
		"npc_id": npc_id,
		"schedule_id": "schedule_villager",
		"map_id": map_id,
		"cell": {"x": 1, "y": 2},
		"facing": "down",
		"behavior_id": "idle",
		"current_event_id": "",
	}
