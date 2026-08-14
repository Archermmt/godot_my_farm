extends ProjectTestCase

const CATALOG_PATH := "res://data/catalogs/core_catalog.tres"


func test_core_catalog_loads_and_is_valid() -> void:
	var catalog: GameCatalog = load(CATALOG_PATH) as GameCatalog
	assert_true(catalog != null)
	assert_equal(DataCatalogService.validate_catalog(catalog), [])
	assert_equal(catalog.items.size(), 23)
	assert_true(catalog.items[_index_of(catalog.items, &"crop_parsnip")] is PlantMeta)
	assert_true(catalog.items[_index_of(catalog.items, &"crop_parsnip")] is HarvestableMeta)
	assert_equal(_count_type(catalog.items, HarvestableMeta), 7)
	for plant_id: StringName in [&"crop_parsnip", &"crop_pumpkin", &"crop_potato"]:
		var plant := catalog.items[_index_of(catalog.items, plant_id)] as PlantMeta
		assert_equal(plant.stages.size(), 4)
		for stage: PlantStage in plant.stages:
			assert_true(stage.texture != null, "%s has a stage without texture" % plant_id)
	assert_equal(catalog.npc_schedules.size(), 1)


func test_empty_and_duplicate_ids_are_reported() -> void:
	var catalog := _valid_minimal_catalog()
	catalog.items[0].id = &""
	var errors: Array[String] = DataCatalogService.validate_catalog(catalog)
	assert_true(_contains(errors, "item[0].id"))
	catalog = _valid_minimal_catalog()
	var duplicate := ItemMeta.new()
	duplicate.id = &"material_test"
	catalog.items.append(duplicate)
	errors = DataCatalogService.validate_catalog(catalog)
	assert_true(_contains(errors, "item duplicate id material_test"))


func test_invalid_stack_and_prices_are_reported() -> void:
	var catalog := _valid_minimal_catalog()
	var item: ItemMeta = catalog.items[0]
	item.stack_limit = 0
	item.buy_price = -1
	item.sell_price = -2
	var errors: Array[String] = DataCatalogService.validate_catalog(catalog)
	assert_true(_contains(errors, "material_test stack_limit"))
	assert_true(_contains(errors, "material_test buy_price"))
	assert_true(_contains(errors, "material_test sell_price"))


func test_invalid_drop_range_and_reference_are_reported() -> void:
	var catalog := _valid_minimal_catalog()
	var entry: HarvestableDrop = (catalog.items[2] as HarvestableMeta).drops[0]
	entry.item_id = &"missing_item"
	entry.min_amount = 4
	entry.max_amount = 2
	entry.chance = 2.0
	var errors: Array[String] = DataCatalogService.validate_catalog(catalog)
	assert_true(_contains(errors, "harvestable harvest_test drops[0].item_id"))
	assert_true(_contains(errors, "harvestable harvest_test drops[0] amount range"))
	assert_true(_contains(errors, "harvestable harvest_test drops[0].chance"))


func test_plant_stage_order_and_cross_references_are_reported() -> void:
	var catalog := _valid_minimal_catalog()
	var plant := catalog.items[1] as PlantMeta
	plant.stages[1].start_day = 0
	var invalid_drop := HarvestableDrop.new()
	invalid_drop.item_id = &"missing_item"
	plant.stages[1].drops = [invalid_drop]
	var errors: Array[String] = DataCatalogService.validate_catalog(catalog)
	assert_true(_contains(errors, "plant_test stages[1].start_day"))
	assert_true(_contains(errors, "plant plant_test stages[1] drops[0].item_id"))


func test_seed_plant_reference_must_point_to_plant_meta() -> void:
	var catalog := _valid_minimal_catalog()
	var seed := catalog.items[0] as SeedMeta
	seed.plant_id = &"material_test"
	var errors: Array[String] = DataCatalogService.validate_catalog(catalog)
	assert_true(_contains(errors, "seed material_test plant_id must reference PlantMeta"))


func test_harvestable_and_schedule_references_are_reported() -> void:
	var catalog := _valid_minimal_catalog()
	var harvestable := catalog.items[2] as HarvestableMeta
	harvestable.max_health = 0
	harvestable.depleted_replacement_id = &"material_test"
	catalog.npc_schedules[0].npc_id = &""
	catalog.npc_schedules[0].events[0].map_id = &""
	var errors: Array[String] = DataCatalogService.validate_catalog(catalog)
	assert_true(_contains(errors, "harvest_test max_health"))
	assert_true(_contains(errors, "harvest_test depleted_replacement_id"))
	assert_true(_contains(errors, "schedule_test npc_id"))
	assert_true(_contains(errors, "event_test map_id"))


func _valid_minimal_catalog() -> GameCatalog:
	var item := SeedMeta.new()
	item.id = &"material_test"
	item.display_name = "Test Material"
	item.item_type = ItemMeta.ItemType.SEED
	item.stack_limit = 10

	var entry := HarvestableDrop.new()
	entry.item_id = item.id

	var stage_a := PlantMeta.make_stage(0)
	var stage_b := PlantMeta.make_stage(1)
	var plant := PlantMeta.new()
	plant.id = &"plant_test"
	plant.stages = [stage_a, stage_b]
	item.plant_id = plant.id

	var harvestable := HarvestableMeta.new()
	harvestable.id = &"harvest_test"
	harvestable.drops = [entry]
	var harvest_stage := HarvestableStage.new()
	harvest_stage.texture = ImageTexture.new()
	harvestable.visual_stages = [harvest_stage]

	var event := NpcScheduleEvent.new()
	event.id = &"event_test"
	event.map_id = &"farm"
	var schedule := NpcSchedule.new()
	schedule.id = &"schedule_test"
	schedule.npc_id = &"npc_test"
	schedule.events = [event]

	var catalog := GameCatalog.new()
	catalog.items = [item, plant, harvestable]
	catalog.npc_schedules = [schedule]
	return catalog


func _contains(errors: Array[String], fragment: String) -> bool:
	for error: String in errors:
		if fragment in error:
			return true
	return false


func _count_type(items: Array[ItemMeta], meta_script: Script) -> int:
	var count := 0
	for item: ItemMeta in items:
		if is_instance_of(item, meta_script):
			count += 1
	return count


func _index_of(items: Array[ItemMeta], item_id: StringName) -> int:
	for index: int in items.size():
		if items[index].id == item_id:
			return index
	return -1
