extends ProjectTestCase

const DATA_CATALOG_SCENE := "res://scenes/autoload/data_catalog.tscn"


func test_service_loads_explicit_catalog_and_indexes_ids() -> void:
	var service := (load(DATA_CATALOG_SCENE) as PackedScene).instantiate() as DataCatalogService
	assert_true(service.initialize(false))
	assert_true(service.is_ready_for_game())
	assert_equal(service.item_count(), 23)
	assert_equal(service.get_item(&"tool_hoe").display_name, "Hoe")
	assert_equal(service.get_seed(&"seed_parsnip").plant_id, &"crop_parsnip")
	assert_equal(service.get_harvestable(&"tree").drops[0].item_id, &"material_wood")
	assert_equal(service.get_npc_schedule(&"schedule_villager").npc_id, &"npc_villager")
	service.free()


func test_bad_catalog_blocks_readiness_with_locatable_error() -> void:
	var item_a := ItemMeta.new()
	item_a.id = &"duplicate"
	var item_b := ItemMeta.new()
	item_b.id = &"duplicate"
	var service := DataCatalogService.new()
	var items: Array[ItemMeta] = [item_a, item_b]
	assert_true(not service.initialize_from_definitions(items, [], false))
	assert_true(not service.is_ready_for_game())
	var errors: Array[String] = service.validation_errors()
	assert_true(not errors.is_empty())
	assert_true("item duplicate id duplicate" in errors[0])
	service.free()
