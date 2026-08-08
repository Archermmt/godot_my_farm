extends ProjectTestCase

const CATALOG_PATH := "res://data/catalogs/core_catalog.tres"


func test_service_loads_explicit_catalog_and_indexes_ids() -> void:
	var service := DataCatalogService.new()
	assert_true(service.load_catalog(CATALOG_PATH, false))
	assert_true(service.is_ready_for_game())
	assert_equal(service.item_count(), 12)
	assert_equal(service.get_item(&"tool_hoe").display_name, "Hoe")
	assert_equal(service.get_crop(&"crop_parsnip").seed_item_id, &"seed_parsnip")
	assert_equal(service.get_drop_table(&"drop_wood").entries[0].item_id, &"material_wood")
	assert_equal(service.get_npc_schedule(&"schedule_villager").npc_id, &"npc_villager")
	service.free()


func test_bad_catalog_blocks_readiness_with_locatable_error() -> void:
	var item_a := ItemDefinition.new()
	item_a.id = &"duplicate"
	var item_b := ItemDefinition.new()
	item_b.id = &"duplicate"
	var bad_catalog := GameCatalog.new()
	bad_catalog.items = [item_a, item_b]
	var service := DataCatalogService.new()
	assert_true(not service.initialize_from_catalog(bad_catalog, false))
	assert_true(not service.is_ready_for_game())
	var errors: Array[String] = service.validation_errors()
	assert_true(not errors.is_empty())
	assert_true("item duplicate id duplicate" in errors[0])
	service.free()
