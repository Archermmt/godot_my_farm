extends ProjectTestCase

func test_autoload_config_catalog_definitions_are_valid() -> void:
	var catalog := DataCatalogService.new()
	assert_true(catalog != null)
	assert_equal(DataCatalogService.validate_definitions(catalog.items, catalog.npc_schedules), [])
	assert_equal(catalog.items.size(), 23)
	for meta: ItemMeta in catalog.items.values():
		assert_true(meta.resource_path.begins_with("res://data/autoload_config.tres::"))
		assert_true(meta.icon_texture != null, "item %s has no icon" % meta.id)
	assert_true(catalog.items[&"crop_parsnip"] is PlantMeta)
	assert_true(catalog.items[&"crop_parsnip"] is HarvestableMeta)
	assert_equal(_count_type(catalog.items, HarvestableMeta), 7)
	for plant_id: StringName in [&"crop_parsnip", &"crop_pumpkin", &"crop_potato"]:
		var plant := catalog.items[plant_id] as PlantMeta
		assert_equal(plant.stages.size(), 4)
		for stage: PlantStage in plant.stages:
			assert_true(stage.texture != null, "%s has a stage without texture" % plant_id)
	assert_equal(catalog.npc_schedules.size(), 2)
	assert_true(catalog.npc_schedules.has(&"schedule_villager"))
	assert_true(catalog.npc_schedules.has(&"schedule_fisher"))
	catalog.free()


func test_empty_and_mismatched_item_keys_are_reported() -> void:
	var definitions := _valid_minimal_definitions()
	var items: Dictionary[StringName, ItemMeta] = definitions["items"]
	var schedules: Dictionary[StringName, NpcSchedule] = definitions["npc_schedules"]
	items[&""] = items[&"material_test"]
	items.erase(&"material_test")
	var errors := DataCatalogService.validate_definitions(items, schedules)
	assert_true(_contains(errors, "empty key"))
	definitions = _valid_minimal_definitions()
	items = definitions["items"]
	schedules = definitions["npc_schedules"]
	items[&"wrong_key"] = items[&"material_test"]
	items.erase(&"material_test")
	errors = DataCatalogService.validate_definitions(items, schedules)
	assert_true(_contains(errors, "items[wrong_key].id must match dictionary key"))


func test_invalid_stack_and_prices_are_reported() -> void:
	var definitions := _valid_minimal_definitions()
	var items: Dictionary[StringName, ItemMeta] = definitions["items"]
	var schedules: Dictionary[StringName, NpcSchedule] = definitions["npc_schedules"]
	var item: ItemMeta = items[&"material_test"]
	item.stack_limit = 0
	item.buy_price = -1
	item.sell_price = -2
	var errors := DataCatalogService.validate_definitions(items, schedules)
	assert_true(_contains(errors, "material_test stack_limit"))
	assert_true(_contains(errors, "material_test buy_price"))
	assert_true(_contains(errors, "material_test sell_price"))


func test_invalid_drop_range_and_reference_are_reported() -> void:
	var definitions := _valid_minimal_definitions()
	var items: Dictionary[StringName, ItemMeta] = definitions["items"]
	var schedules: Dictionary[StringName, NpcSchedule] = definitions["npc_schedules"]
	var entry: HarvestableDrop = (items[&"harvest_test"] as HarvestableMeta).drops[0]
	entry.item_id = &"missing_item"
	entry.min_amount = 4
	entry.max_amount = 2
	entry.chance = 2.0
	var errors := DataCatalogService.validate_definitions(items, schedules)
	assert_true(_contains(errors, "harvestable harvest_test drops[0].item_id"))
	assert_true(_contains(errors, "harvestable harvest_test drops[0] amount range"))
	assert_true(_contains(errors, "harvestable harvest_test drops[0].chance"))


func test_plant_stage_order_and_cross_references_are_reported() -> void:
	var definitions := _valid_minimal_definitions()
	var items: Dictionary[StringName, ItemMeta] = definitions["items"]
	var schedules: Dictionary[StringName, NpcSchedule] = definitions["npc_schedules"]
	var plant := items[&"plant_test"] as PlantMeta
	plant.stages[1].start_day = 0
	var invalid_drop := HarvestableDrop.new()
	invalid_drop.item_id = &"missing_item"
	plant.stages[1].drops = [invalid_drop]
	var errors := DataCatalogService.validate_definitions(items, schedules)
	assert_true(_contains(errors, "plant_test stages[1].start_day"))
	assert_true(_contains(errors, "plant plant_test stages[1] drops[0].item_id"))


func test_seed_plant_reference_must_point_to_plant_meta() -> void:
	var definitions := _valid_minimal_definitions()
	var items: Dictionary[StringName, ItemMeta] = definitions["items"]
	var schedules: Dictionary[StringName, NpcSchedule] = definitions["npc_schedules"]
	var seed := items[&"material_test"] as SeedMeta
	seed.plant_id = &"material_test"
	var errors := DataCatalogService.validate_definitions(items, schedules)
	assert_true(_contains(errors, "seed material_test plant_id must reference PlantMeta"))


func test_harvestable_and_schedule_references_are_reported() -> void:
	var definitions := _valid_minimal_definitions()
	var items: Dictionary[StringName, ItemMeta] = definitions["items"]
	var schedules: Dictionary[StringName, NpcSchedule] = definitions["npc_schedules"]
	var harvestable := items[&"harvest_test"] as HarvestableMeta
	harvestable.max_health = 0
	harvestable.depleted_replacement_id = &"material_test"
	schedules[&"schedule_test"].npc_id = &""
	schedules[&"schedule_test"].events[0].map_id = &""
	var errors := DataCatalogService.validate_definitions(items, schedules)
	assert_true(_contains(errors, "harvest_test max_health"))
	assert_true(_contains(errors, "harvest_test depleted_replacement_id"))
	assert_true(_contains(errors, "schedule_test npc_id"))
	assert_true(_contains(errors, "event_test map_id"))


func _valid_minimal_definitions() -> Dictionary:
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

	var items: Dictionary[StringName, ItemMeta] = {
		item.id: item,
		plant.id: plant,
		harvestable.id: harvestable,
	}
	var schedules: Dictionary[StringName, NpcSchedule] = {schedule.id: schedule}
	return {
		"items": items,
		"npc_schedules": schedules,
	}


func _contains(errors: Array[String], fragment: String) -> bool:
	for error: String in errors:
		if fragment in error:
			return true
	return false


func _count_type(items: Dictionary[StringName, ItemMeta], meta_script: Script) -> int:
	var count := 0
	for item: ItemMeta in items.values():
		if is_instance_of(item, meta_script):
			count += 1
	return count
