extends ProjectTestCase


func test_game_config_catalog_definitions_are_valid() -> void:
	assert_true(DataCatalog.setup().is_empty())
	assert_true(DataCatalog.config.items.size() > 0)
	assert_true(DataCatalog.get_item(&"hoe") is ToolMeta)
	assert_true(DataCatalog.get_item(&"parsnip") is PlantMeta)


func test_catalog_indexes_npc_schedules_by_owner() -> void:
	var schedules := DataCatalog.get_npc_schedules(&"npc_villager")
	assert_true(not schedules.is_empty())
	for schedule: NpcSchedule in schedules:
		assert_true(schedule.map_id != &"")
		assert_true(schedule.wander_zone.x >= 0.0)
