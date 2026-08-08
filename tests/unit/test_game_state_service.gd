extends ProjectTestCase

const CATALOG_PATH := "res://data/catalogs/core_catalog.tres"


func test_new_game_is_deterministic_and_does_not_accumulate_inventory() -> void:
	var catalog_service := _catalog_service()
	var game_state := GameStateService.new()
	game_state.configure(catalog_service)
	var connections_before: int = EventBus.inventory_changed.get_connections().size()
	assert_equal(game_state.new_game(4242), OK)
	var first: Dictionary = game_state.snapshot()
	assert_equal(game_state.inventory.capacity(), 20)
	assert_equal(game_state.inventory.count_item(&"seed_parsnip"), 15)
	for tool_id: StringName in GameStateService.INITIAL_TOOL_IDS:
		assert_equal(game_state.inventory.count_item(tool_id), 1)
	assert_equal(game_state.player.map_id, &"cabin")
	assert_equal(game_state.player.spawn_id, &"wake")
	assert_equal(game_state.new_game(4242), OK)
	assert_equal(game_state.snapshot(), first)
	assert_equal(EventBus.inventory_changed.get_connections().size(), connections_before)
	game_state.free()
	catalog_service.free()


func test_different_seed_changes_only_seed_in_initial_snapshot() -> void:
	var catalog_service := _catalog_service()
	var game_state := GameStateService.new()
	game_state.configure(catalog_service)
	assert_equal(game_state.new_game(100), OK)
	var first: Dictionary = game_state.snapshot()
	assert_equal(game_state.new_game(200), OK)
	var second: Dictionary = game_state.snapshot()
	assert_true(first != second)
	first["world_seed"] = 200
	assert_equal(first, second)
	game_state.free()
	catalog_service.free()


func test_snapshot_is_deep_copy_and_replace_is_atomic() -> void:
	var catalog_service := _catalog_service()
	var game_state := GameStateService.new()
	game_state.configure(catalog_service)
	assert_equal(game_state.new_game(77), OK)
	var snapshot: Dictionary = game_state.snapshot()
	var player_data: Dictionary = snapshot["player"]
	player_data["gold"] = 999999
	var inventory_data: Dictionary = snapshot["inventory"]
	var slots: Array = inventory_data["slots"]
	var first_slot: Dictionary = slots[0]
	first_slot["amount"] = 99
	assert_equal(game_state.player.gold, 500)
	assert_equal(game_state.inventory.slots[0].amount, 1)

	var before: Dictionary = game_state.snapshot()
	var invalid: Dictionary = before.duplicate(true)
	invalid["player"] = {"gold": -1}
	assert_equal(game_state.replace_snapshot(invalid), ERR_INVALID_DATA)
	assert_equal(game_state.snapshot(), before)
	game_state.free()
	catalog_service.free()


func test_reset_and_unconfigured_new_game_are_explicit() -> void:
	var game_state := GameStateService.new()
	assert_equal(game_state.new_game(1), ERR_UNCONFIGURED)
	assert_true(not game_state.is_initialized())
	var catalog_service := _catalog_service()
	game_state.configure(catalog_service)
	assert_equal(game_state.new_game(1), OK)
	game_state.reset()
	assert_true(not game_state.is_initialized())
	assert_equal(game_state.snapshot(), {})
	game_state.free()
	catalog_service.free()


func _catalog_service() -> DataCatalogService:
	var service := DataCatalogService.new()
	service.load_catalog(CATALOG_PATH, false)
	return service
