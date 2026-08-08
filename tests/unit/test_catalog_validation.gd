extends ProjectTestCase

const CATALOG_PATH := "res://data/catalogs/core_catalog.tres"


func test_core_catalog_loads_and_is_valid() -> void:
	var catalog: GameCatalog = load(CATALOG_PATH) as GameCatalog
	assert_true(catalog != null)
	assert_equal(CatalogValidator.validate(catalog), [])
	assert_equal(catalog.items.size(), 12)
	assert_equal(catalog.crops.size(), 1)
	assert_equal(catalog.harvestables.size(), 3)
	assert_equal(catalog.drop_tables.size(), 4)
	assert_equal(catalog.npc_schedules.size(), 1)


func test_empty_and_duplicate_ids_are_reported() -> void:
	var catalog := _valid_minimal_catalog()
	catalog.items[0].id = &""
	var errors: Array[String] = CatalogValidator.validate(catalog)
	assert_true(_contains(errors, "item[0].id"))
	catalog = _valid_minimal_catalog()
	var duplicate := ItemDefinition.new()
	duplicate.id = &"material_test"
	catalog.items.append(duplicate)
	errors = CatalogValidator.validate(catalog)
	assert_true(_contains(errors, "item duplicate id material_test"))


func test_invalid_stack_and_prices_are_reported() -> void:
	var catalog := _valid_minimal_catalog()
	var item: ItemDefinition = catalog.items[0]
	item.stack_limit = 0
	item.buy_price = -1
	item.sell_price = -2
	var errors: Array[String] = CatalogValidator.validate(catalog)
	assert_true(_contains(errors, "material_test stack_limit"))
	assert_true(_contains(errors, "material_test buy_price"))
	assert_true(_contains(errors, "material_test sell_price"))


func test_invalid_drop_range_and_reference_are_reported() -> void:
	var catalog := _valid_minimal_catalog()
	var entry: DropTableEntry = catalog.drop_tables[0].entries[0]
	entry.item_id = &"missing_item"
	entry.min_amount = 4
	entry.max_amount = 2
	entry.chance = 2.0
	entry.weight = 0
	var errors: Array[String] = CatalogValidator.validate(catalog)
	assert_true(_contains(errors, "drop_test entries[0].item_id"))
	assert_true(_contains(errors, "drop_test entries[0] amount range"))
	assert_true(_contains(errors, "drop_test entries[0].chance"))
	assert_true(_contains(errors, "drop_test entries[0].weight"))


func test_crop_stage_order_and_cross_references_are_reported() -> void:
	var catalog := _valid_minimal_catalog()
	var crop: CropDefinition = catalog.crops[0]
	crop.seed_item_id = &"missing_seed"
	crop.produce_item_id = &"missing_produce"
	crop.harvest_drop_table_id = &"missing_drop"
	crop.stages[1].start_day = 0
	crop.stages[1].drop_table_id = &"missing_stage_drop"
	var errors: Array[String] = CatalogValidator.validate(catalog)
	assert_true(_contains(errors, "crop_test seed_item_id"))
	assert_true(_contains(errors, "crop_test produce_item_id"))
	assert_true(_contains(errors, "crop_test harvest_drop_table_id"))
	assert_true(_contains(errors, "crop_test stages[1].start_day"))
	assert_true(_contains(errors, "crop_test stages[1].drop_table_id"))


func test_seed_harvestable_and_schedule_references_are_reported() -> void:
	var catalog := _valid_minimal_catalog()
	catalog.items[0].item_type = ItemDefinition.ItemType.SEED
	catalog.items[0].related_crop_id = &"missing_crop"
	catalog.harvestables[0].max_health = 0
	catalog.harvestables[0].drop_table_id = &"missing_drop"
	catalog.npc_schedules[0].npc_id = &""
	catalog.npc_schedules[0].events[0].map_id = &""
	var errors: Array[String] = CatalogValidator.validate(catalog)
	assert_true(_contains(errors, "material_test related_crop_id"))
	assert_true(_contains(errors, "harvest_test max_health"))
	assert_true(_contains(errors, "harvest_test drop_table_id"))
	assert_true(_contains(errors, "schedule_test npc_id"))
	assert_true(_contains(errors, "event_test map_id"))


func _valid_minimal_catalog() -> GameCatalog:
	var item := ItemDefinition.new()
	item.id = &"material_test"
	item.display_name = "Test Material"
	item.stack_limit = 10

	var entry := DropTableEntry.new()
	entry.item_id = item.id
	var table := DropTable.new()
	table.id = &"drop_test"
	table.entries = [entry]

	var stage_a := GrowthStageDefinition.new()
	stage_a.start_day = 0
	var stage_b := GrowthStageDefinition.new()
	stage_b.start_day = 1
	var crop := CropDefinition.new()
	crop.id = &"crop_test"
	crop.seed_item_id = item.id
	crop.produce_item_id = item.id
	crop.harvest_drop_table_id = table.id
	crop.stages = [stage_a, stage_b]

	var harvestable := HarvestableDefinition.new()
	harvestable.id = &"harvest_test"
	harvestable.drop_table_id = table.id

	var event := NpcScheduleEvent.new()
	event.id = &"event_test"
	event.map_id = &"farm"
	var schedule := NpcSchedule.new()
	schedule.id = &"schedule_test"
	schedule.npc_id = &"npc_test"
	schedule.events = [event]

	var catalog := GameCatalog.new()
	catalog.items = [item]
	catalog.crops = [crop]
	catalog.harvestables = [harvestable]
	catalog.drop_tables = [table]
	catalog.npc_schedules = [schedule]
	return catalog


func _contains(errors: Array[String], fragment: String) -> bool:
	for error: String in errors:
		if fragment in error:
			return true
	return false
