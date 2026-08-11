extends ProjectTestCase

const CATALOG_PATH := "res://data/catalogs/core_catalog.tres"


func test_new_game_is_deterministic_and_does_not_accumulate_inventory() -> void:
	var catalog_service := _catalog_service()
	var game_manager := GameManagerService.new()
	game_manager.configure(catalog_service)
	var connections_before: int = EventBus.inventory_changed.get_connections().size()
	assert_equal(game_manager.new_game(4242), OK)
	var first: Dictionary = game_manager.snapshot()
	assert_equal(game_manager.player.inventory.capacity(), 20)
	assert_equal(game_manager.player.toolbar.capacity(), 6)
	assert_equal(game_manager.player.itembar.capacity(), 10)
	assert_equal(game_manager.player.itembar.count_item(&"seed_parsnip"), 15)
	assert_equal(game_manager.player.inventory.count_item(&"seed_parsnip"), 0)
	for tool_id: StringName in PlayerState.INITIAL_TOOL_IDS:
		assert_equal(game_manager.player.toolbar.count_item(tool_id), 1)
	assert_equal(game_manager.player.map_id, &"cabin")
	assert_equal(game_manager.player.spawn_id, &"wake")
	assert_equal(game_manager.new_game(4242), OK)
	assert_equal(game_manager.snapshot(), first)
	assert_equal(EventBus.inventory_changed.get_connections().size(), connections_before)
	game_manager.free()
	catalog_service.free()


func test_different_seed_changes_only_seed_in_initial_snapshot() -> void:
	var catalog_service := _catalog_service()
	var game_manager := GameManagerService.new()
	game_manager.configure(catalog_service)
	assert_equal(game_manager.new_game(100), OK)
	var first: Dictionary = game_manager.snapshot()
	assert_equal(game_manager.new_game(200), OK)
	var second: Dictionary = game_manager.snapshot()
	assert_true(first != second)
	first["world_seed"] = 200
	assert_equal(first, second)
	game_manager.free()
	catalog_service.free()


func test_snapshot_is_deep_copy_and_replace_is_atomic() -> void:
	var catalog_service := _catalog_service()
	var game_manager := GameManagerService.new()
	game_manager.configure(catalog_service)
	assert_equal(game_manager.new_game(77), OK)
	var snapshot: Dictionary = game_manager.snapshot()
	var player_data: Dictionary = snapshot["player"]
	player_data["gold"] = 999999
	var toolbar_data: Dictionary = (snapshot["player"] as Dictionary)["toolbar"]
	var slots: Array = toolbar_data["slots"]
	var first_slot: Dictionary = slots[0]
	first_slot["amount"] = 99
	assert_equal(game_manager.player.gold, 500)
	assert_equal(game_manager.player.toolbar.slots[0].amount, 1)

	var before: Dictionary = game_manager.snapshot()
	var invalid: Dictionary = before.duplicate(true)
	invalid["player"] = {"gold": -1}
	assert_equal(game_manager.replace_snapshot(invalid), ERR_INVALID_DATA)
	assert_equal(game_manager.snapshot(), before)
	game_manager.free()
	catalog_service.free()


func test_combined_snapshot_round_trips_game_and_time_state() -> void:
	var catalog_service := _catalog_service()
	var game_manager := GameManagerService.new()
	game_manager.configure(catalog_service)
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
	catalog_service.free()


func test_npcs_are_global_and_keep_their_current_map_location() -> void:
	var catalog_service := _catalog_service()
	var game_manager := GameManagerService.new()
	game_manager.configure(catalog_service)
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
	catalog_service.free()


func test_replace_snapshot_rejects_invalid_or_duplicate_global_npcs_atomically() -> void:
	var catalog_service := _catalog_service()
	var game_manager := GameManagerService.new()
	game_manager.configure(catalog_service)
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
	catalog_service.free()


func test_reset_and_unconfigured_new_game_are_explicit() -> void:
	var game_manager := GameManagerService.new()
	assert_equal(game_manager.new_game(1), ERR_UNCONFIGURED)
	assert_true(not game_manager.is_initialized())
	var catalog_service := _catalog_service()
	game_manager.configure(catalog_service)
	assert_equal(game_manager.new_game(1), OK)
	game_manager.reset()
	assert_true(not game_manager.is_initialized())
	assert_equal(game_manager.snapshot(), {})
	game_manager.free()
	catalog_service.free()


func test_bar_selection_switches_the_single_active_hand() -> void:
	var catalog_service := _catalog_service()
	var game_manager := GameManagerService.new()
	game_manager.configure(catalog_service)
	assert_equal(game_manager.new_game(7), OK)
	assert_equal(game_manager.player.active_hand_source, PlayerState.ActiveHandSource.NONE)
	assert_true(game_manager.player.active_stack().is_empty())
	assert_equal(game_manager.player.select_bar_relative(PlayerState.ActiveHandSource.ITEMBAR, 1), OK)
	assert_equal(game_manager.player.active_hand_source, PlayerState.ActiveHandSource.ITEMBAR)
	assert_true(game_manager.player.active_stack().is_empty())
	assert_equal(game_manager.player.select_bar_index(PlayerState.ActiveHandSource.ITEMBAR, 0), OK)
	assert_equal(game_manager.player.active_stack().item_id, &"seed_parsnip")
	assert_equal(game_manager.player.select_bar_relative(PlayerState.ActiveHandSource.TOOLBAR, -1), OK)
	assert_equal(game_manager.player.active_hand_source, PlayerState.ActiveHandSource.TOOLBAR)
	assert_equal(game_manager.player.active_stack().item_id, &"tool_axe")
	game_manager.free()
	catalog_service.free()


func test_cross_container_exchange_enforces_types_and_merges_atomically() -> void:
	var catalog_service := _catalog_service()
	var game_manager := GameManagerService.new()
	game_manager.configure(catalog_service)
	assert_equal(game_manager.new_game(7), OK)
	var before := game_manager.snapshot()
	assert_equal(game_manager.player.exchange_container_slots(&"toolbar", 0, &"itembar", 1, catalog_service.get_item(&"tool_hoe"), catalog_service.get_item(&"seed_parsnip")), ERR_UNAVAILABLE)
	assert_equal(game_manager.snapshot(), before)
	assert_true(game_manager.player.inventory.set_slot(0, ItemStack.new(&"seed_parsnip", 10)))
	assert_equal(game_manager.player.exchange_container_slots(&"inventory", 0, &"itembar", 0, catalog_service.get_item(&"seed_parsnip"), catalog_service.get_item(&"seed_parsnip")), OK)
	assert_true(game_manager.player.inventory.get_slot(0).is_empty())
	assert_equal(game_manager.player.itembar.get_slot(0).amount, 25)
	assert_true(game_manager.player.inventory.set_slot(1, ItemStack.new(&"material_wood", 3)))
	assert_equal(game_manager.player.exchange_container_slots(&"inventory", 1, &"itembar", 1, catalog_service.get_item(&"material_wood"), null), OK)
	assert_equal(game_manager.player.itembar.get_slot(1).item_id, &"material_wood")
	assert_equal(game_manager.player.exchange_container_slots(&"itembar", 1, &"toolbar", 0, catalog_service.get_item(&"material_wood"), catalog_service.get_item(&"tool_hoe")), ERR_UNAVAILABLE)
	game_manager.free()
	catalog_service.free()


func test_toolbar_itembar_and_active_hand_round_trip() -> void:
	var catalog_service := _catalog_service()
	var game_manager := GameManagerService.new()
	game_manager.configure(catalog_service)
	assert_equal(game_manager.new_game(7), OK)
	assert_equal(game_manager.player.select_bar_index(PlayerState.ActiveHandSource.ITEMBAR, 0), OK)
	var snapshot := JSON.parse_string(JSON.stringify(game_manager.snapshot())) as Dictionary
	assert_equal(game_manager.new_game(8), OK)
	assert_equal(game_manager.replace_snapshot(snapshot), OK)
	assert_equal(game_manager.player.active_hand_source, PlayerState.ActiveHandSource.ITEMBAR)
	assert_equal(game_manager.player.toolbar.count_item(&"tool_pickaxe"), 1)
	assert_equal(game_manager.player.itembar.count_item(&"seed_parsnip"), 15)
	assert_equal(game_manager.player.active_stack().item_id, &"seed_parsnip")
	game_manager.free()
	catalog_service.free()


func _catalog_service() -> DataCatalogService:
	var service := DataCatalogService.new()
	service.load_catalog(CATALOG_PATH, false)
	return service


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
