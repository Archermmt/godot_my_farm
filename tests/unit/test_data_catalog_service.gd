extends ProjectTestCase

func test_service_loads_explicit_catalog_and_indexes_ids() -> void:
	var service := DataCatalogService.new()
	assert_true(service.setup().is_empty())
	assert_equal(service.config.items.size(), 23)
	assert_equal(service.get_item(&"hoe").display_name, "Hoe")
	assert_equal((service.get_item(&"parsnip_seed") as SeedMeta).plant_id, &"parsnip")
	assert_equal((service.get_item(&"tree") as HarvestableMeta).stages.back().drops[0].item_id, &"wood")
	assert_equal(service.get_npc_schedule(&"morning_farm").map_id, &"farm")
	assert_equal(service.get_npc_schedule(&"day_field").map_id, &"field")
	service.free()


func test_catalog_validation_reports_locatable_error() -> void:
	var item_a := ItemMeta.new()
	item_a.id = &"duplicate"
	var items: Dictionary[StringName, ItemMeta] = {&"wrong_key": item_a}
	var service := DataCatalogService.new()
	service.config = DataCatalog.config.duplicate(true) as GameConfig
	service.config.items = items
	var errors: Array[String] = service.setup()
	assert_true(not errors.is_empty())
	assert_true("items[wrong_key].id must match dictionary key" in errors[0])
