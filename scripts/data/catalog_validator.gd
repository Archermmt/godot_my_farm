class_name CatalogValidator
extends RefCounted


static func validate(catalog: GameCatalog) -> Array[String]:
	var errors: Array[String] = []
	if catalog == null:
		return ["catalog: resource is null"]

	var item_ids := _collect_ids(catalog.items, "item", errors)
	var crop_ids := _collect_ids(catalog.crops, "crop", errors)
	var harvestable_ids := _collect_ids(catalog.harvestables, "harvestable", errors)
	var drop_table_ids := _collect_ids(catalog.drop_tables, "drop_table", errors)
	var schedule_ids := _collect_ids(catalog.npc_schedules, "npc_schedule", errors)
	var _unused_ids := [harvestable_ids, schedule_ids]

	for item: ItemDefinition in catalog.items:
		if item == null:
			continue
		if item.stack_limit <= 0:
			errors.append("item %s stack_limit must be positive" % item.id)
		if item.buy_price < 0:
			errors.append("item %s buy_price must be non-negative" % item.id)
		if item.sell_price < 0:
			errors.append("item %s sell_price must be non-negative" % item.id)
		if item.item_type == ItemDefinition.ItemType.SEED:
			if item.related_crop_id == &"" or not crop_ids.has(item.related_crop_id):
				errors.append("item %s related_crop_id missing crop %s" % [item.id, item.related_crop_id])

	for table: DropTable in catalog.drop_tables:
		if table == null:
			continue
		for index: int in table.entries.size():
			var entry: DropTableEntry = table.entries[index]
			if entry == null:
				errors.append("drop_table %s entries[%d] is null" % [table.id, index])
				continue
			if entry.item_id == &"" or not item_ids.has(entry.item_id):
				errors.append("drop_table %s entries[%d].item_id missing item %s" % [table.id, index, entry.item_id])
			if entry.min_amount < 0 or entry.max_amount < entry.min_amount:
				errors.append("drop_table %s entries[%d] amount range invalid" % [table.id, index])
			if entry.chance < 0.0 or entry.chance > 1.0:
				errors.append("drop_table %s entries[%d].chance invalid" % [table.id, index])
			if entry.weight <= 0:
				errors.append("drop_table %s entries[%d].weight must be positive" % [table.id, index])

	for crop: CropDefinition in catalog.crops:
		if crop == null:
			continue
		if crop.seed_item_id == &"" or not item_ids.has(crop.seed_item_id):
			errors.append("crop %s seed_item_id missing item %s" % [crop.id, crop.seed_item_id])
		if crop.produce_item_id == &"" or not item_ids.has(crop.produce_item_id):
			errors.append("crop %s produce_item_id missing item %s" % [crop.id, crop.produce_item_id])
		if crop.harvest_drop_table_id != &"" and not drop_table_ids.has(crop.harvest_drop_table_id):
			errors.append("crop %s harvest_drop_table_id missing drop_table %s" % [crop.id, crop.harvest_drop_table_id])
		if crop.stages.is_empty():
			errors.append("crop %s stages must not be empty" % crop.id)
		var previous_day: int = -1
		for index: int in crop.stages.size():
			var stage: GrowthStageDefinition = crop.stages[index]
			if stage == null:
				errors.append("crop %s stages[%d] is null" % [crop.id, index])
				continue
			if stage.start_day <= previous_day:
				errors.append("crop %s stages[%d].start_day must increase" % [crop.id, index])
			previous_day = stage.start_day
			if stage.max_health <= 0:
				errors.append("crop %s stages[%d].max_health must be positive" % [crop.id, index])
			if stage.drop_table_id != &"" and not drop_table_ids.has(stage.drop_table_id):
				errors.append("crop %s stages[%d].drop_table_id missing drop_table %s" % [crop.id, index, stage.drop_table_id])

	for harvestable: HarvestableDefinition in catalog.harvestables:
		if harvestable == null:
			continue
		if harvestable.max_health <= 0:
			errors.append("harvestable %s max_health must be positive" % harvestable.id)
		if harvestable.drop_table_id != &"" and not drop_table_ids.has(harvestable.drop_table_id):
			errors.append("harvestable %s drop_table_id missing drop_table %s" % [harvestable.id, harvestable.drop_table_id])

	for schedule: NpcSchedule in catalog.npc_schedules:
		if schedule == null:
			continue
		if schedule.npc_id == &"":
			errors.append("npc_schedule %s npc_id must not be empty" % schedule.id)
		var event_ids: Dictionary = {}
		for index: int in schedule.events.size():
			var event: NpcScheduleEvent = schedule.events[index]
			if event == null:
				errors.append("npc_schedule %s events[%d] is null" % [schedule.id, index])
				continue
			if event.id == &"":
				errors.append("npc_schedule %s events[%d].id must not be empty" % [schedule.id, index])
			elif event_ids.has(event.id):
				errors.append("npc_schedule %s duplicate event id %s" % [schedule.id, event.id])
			event_ids[event.id] = true
			if event.start_minute < 0 or event.start_minute > 1439:
				errors.append("npc_schedule %s event %s start_minute invalid" % [schedule.id, event.id])
			if event.duration_minutes <= 0:
				errors.append("npc_schedule %s event %s duration_minutes invalid" % [schedule.id, event.id])
			if event.map_id == &"":
				errors.append("npc_schedule %s event %s map_id must not be empty" % [schedule.id, event.id])

	return errors


static func _collect_ids(resources: Array, kind: String, errors: Array[String]) -> Dictionary:
	var ids: Dictionary = {}
	for index: int in resources.size():
		var resource: Resource = resources[index]
		if resource == null:
			errors.append("%s[%d] is null" % [kind, index])
			continue
		var id_value: StringName = resource.get("id") as StringName
		if id_value == &"":
			errors.append("%s[%d].id must not be empty" % [kind, index])
			continue
		if ids.has(id_value):
			errors.append("%s duplicate id %s" % [kind, id_value])
		ids[id_value] = true
	return ids
