extends ProjectTestCase

const EXPECTED_AUTOLOAD_ORDER: Array[String] = [
	"EventBus",
	"DataCatalog",
	"GameManager",
	"MapManager",
	"CalendarManager",
	"EffectManager",
	"AudioManager",
]


func test_game_services_start_in_architecture_order() -> void:
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	var root_names: Array[String] = []
	for child: Node in scene_tree.root.get_children():
		root_names.append(child.name)
	var previous_index: int = -1
	for autoload_name: String in EXPECTED_AUTOLOAD_ORDER:
		var current_index: int = root_names.find(autoload_name)
		assert_true(current_index >= 0, "Missing autoload %s" % autoload_name)
		assert_true(current_index > previous_index, "Autoload %s is out of order" % autoload_name)
		previous_index = current_index


func test_autoload_definitions_and_new_game_are_ready() -> void:
	assert_true(DataCatalog.is_ready_for_game())
	assert_equal((DataCatalog.get_item(&"hoe") as ToolMeta).tool_kind, ToolMeta.ToolKind.HOE)
	assert_true(GameManager.is_initialized())
	assert_equal(GameManager.player.map_id, &"farm")
	assert_equal(GameManager.player.spawn_id, &"default")
	assert_equal(GameManager.player.backpack_state.count_item(&"itembar", &"parsnip_seed"), 15)
	assert_equal(GameManager.player.backpack_state.count_item(&"toolbar", &"hoe"), 1)
	assert_equal(GameManager.used_inventory_slots(), 0)
	assert_true(GameManager.can_snapshot())


func test_configurable_managers_load_shared_game_config() -> void:
	assert_true(GameManager.config == DataCatalog.config)
	assert_true(MapManager.config == DataCatalog.config)
	assert_true(CalendarManager.config == DataCatalog.config)
	assert_true(EffectManager.config == DataCatalog.config)
	assert_true(AudioManager.config == DataCatalog.config)
	assert_equal(GameManager.config.initial_time_scale, 1.0)
	assert_equal(GameManager.time_scale, 1.0)
	assert_equal(MapManager.config.transition_duration, 0.12)
	assert_equal(MapManager.config.day_transition_duration, 0.55)
	assert_true(CalendarManager.is_configured())
	assert_equal(CalendarManager.config.season_metas.size(), 4)
	assert_equal(CalendarManager.season_id_for_month(1), &"spring")
	assert_true(CalendarManager.current_weather_id() != &"")
	assert_equal(AudioManager.config.audio_definitions.size(), 18)
	assert_equal(AudioManager.config.sfx_pool_limit, 10)
	assert_true(EffectManager.is_configured())
	assert_equal(EffectManager.definition_count(), 7)
	assert_equal(EffectManager.weather_scene_count(), 4)
