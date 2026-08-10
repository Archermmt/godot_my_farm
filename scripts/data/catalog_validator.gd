class_name CatalogValidator
extends RefCounted


static func validate(catalog: GameCatalog) -> Array[String]:
	var errors: Array[String] = []
	if catalog == null:
		return ["catalog: resource is null"]

	var item_ids := _collect_ids(catalog.items, "item", errors)
	var drop_table_ids := _collect_ids(catalog.drop_tables, "drop_table", errors)
	var schedule_ids := _collect_ids(catalog.npc_schedules, "npc_schedule", errors)
	var _unused_ids := [schedule_ids]

	for item: ItemMeta in catalog.items:
		if item == null:
			continue
		if item.stack_limit <= 0:
			errors.append("item %s stack_limit must be positive" % item.id)
		if item.buy_price < 0:
			errors.append("item %s buy_price must be non-negative" % item.id)
		if item.sell_price < 0:
			errors.append("item %s sell_price must be non-negative" % item.id)
		if item is ToolMeta and item.item_type != ItemMeta.ItemType.TOOL:
			errors.append("tool %s item_type must be TOOL" % item.id)
		if item is PlantMeta:
			_validate_harvestable(item as PlantMeta, drop_table_ids, errors)
			_validate_plant(item as PlantMeta, item_ids, drop_table_ids, errors)
		elif item is HarvestableMeta:
			_validate_harvestable(item as HarvestableMeta, drop_table_ids, errors)

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


static func _validate_plant(plant: PlantMeta, item_ids: Dictionary, drop_table_ids: Dictionary, errors: Array[String]) -> void:
	if plant.seed_item_id != &"":
		var seed_meta := item_ids.get(plant.seed_item_id, null) as ItemMeta
		if seed_meta == null:
			errors.append("plant %s seed_item_id missing item %s" % [plant.id, plant.seed_item_id])
		elif seed_meta.item_type != ItemMeta.ItemType.SEED:
			errors.append("plant %s seed_item_id must reference SEED item %s" % [plant.id, plant.seed_item_id])
	if plant.stages.is_empty():
		errors.append("plant %s stages must not be empty" % plant.id)
	var previous_day: int = -1
	for index: int in plant.stages.size():
		var stage: Dictionary = plant.stages[index]
		if not PlantMeta.is_stage_struct(stage):
			errors.append("plant %s stages[%d] has invalid structure" % [plant.id, index])
			continue
		var start_day := int(stage.get("start_day", 0))
		var max_health := int(stage.get("max_health", 0))
		var drop_table_id := stage.get("drop_table_id", &"") as StringName
		if start_day <= previous_day:
			errors.append("plant %s stages[%d].start_day must increase" % [plant.id, index])
		previous_day = start_day
		if max_health <= 0:
			errors.append("plant %s stages[%d].max_health must be positive" % [plant.id, index])
		if drop_table_id != &"" and not drop_table_ids.has(drop_table_id):
			errors.append("plant %s stages[%d].drop_table_id missing drop_table %s" % [plant.id, index, drop_table_id])


static func _validate_harvestable(harvestable: HarvestableMeta, drop_table_ids: Dictionary, errors: Array[String]) -> void:
	if harvestable.max_health <= 0:
		errors.append("harvestable %s max_health must be positive" % harvestable.id)
	if harvestable.drop_table_id != &"" and not drop_table_ids.has(harvestable.drop_table_id):
		errors.append("harvestable %s drop_table_id missing drop_table %s" % [harvestable.id, harvestable.drop_table_id])


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
		ids[id_value] = resource
	return ids
