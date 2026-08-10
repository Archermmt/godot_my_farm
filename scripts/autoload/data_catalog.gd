class_name DataCatalogService
extends Node

const DEFAULT_CONFIG_PATH := "res://data/game_config.tres"

var config: GameConfig = load(DEFAULT_CONFIG_PATH) as GameConfig


func summary() -> String:
	return (
		"items=%d plants=%d harvestables=%d schedules=%d"
		% [
			config.items.size(),
			_count_meta_type(PlantMeta),
			_count_meta_type(HarvestableMeta),
			config.npc_schedules.size(),
		]
	)


func get_item(id: StringName) -> ItemMeta:
	var meta: ItemMeta = config.items.get(id) as ItemMeta
	if meta == null:
		push_error("[DataCatalog] unknown item id: %s" % id)
	return meta


func get_npc_schedule(id: StringName) -> NpcSchedule:
	var definition: NpcSchedule = null
	for entries: Array in config.npc_schedules.values():
		for candidate: NpcSchedule in entries:
			if candidate != null and candidate.id == id:
				definition = candidate
				break
		if definition != null:
			break
	if definition == null:
		push_error("[DataCatalog] unknown NPC schedule id: %s" % id)
	return definition


func get_npc_schedules(npc_id: StringName) -> Array[NpcSchedule]:
	var result: Array[NpcSchedule] = []
	for schedule: NpcSchedule in config.npc_schedules.get(npc_id, []):
		if schedule != null:
			result.append(schedule)
	return result


func has_item(id: StringName) -> bool:
	return config.items.has(id)


func setup() -> Array[String]:
	var item_definitions := config.items
	var schedule_definitions := config.npc_schedules
	var errors: Array[String] = []
	var item_ids := _validate_item_dictionary(item_definitions, errors)
	_validate_schedule_dictionary(schedule_definitions, errors)
	for item: ItemMeta in item_definitions.values():
		if item == null:
			continue
		if item.stack_limit <= 0:
			errors.append("item %s stack_limit must be positive" % item.id)
		if item.buy_price < 0:
			errors.append("item %s buy_price must be non-negative" % item.id)
		if item.sell_price < 0:
			errors.append("item %s sell_price must be non-negative" % item.id)
		if item is ToolMeta and not item is SeedMeta:
			_validate_tool(item as ToolMeta, errors)
		if item is SeedMeta:
			_validate_seed(item as SeedMeta, item_ids, errors)
		if item is PlantMeta:
			_validate_harvestable(item as PlantMeta, item_ids, errors)
			_validate_plant(item as PlantMeta, item_ids, errors)
		elif item is HarvestableMeta:
			_validate_harvestable(item as HarvestableMeta, item_ids, errors)

	for schedule_list: Array in schedule_definitions.values():
		for schedule: NpcSchedule in schedule_list:
			if schedule == null:
				continue
			if schedule.start_minute < 0 or schedule.start_minute > 1439:
				errors.append("npc_schedule %s start_minute invalid" % schedule.id)
			if schedule.map_id == &"":
				errors.append("npc_schedule %s map_id must not be empty" % schedule.id)
			for season: SeasonMeta.SeasonType in schedule.seasons:
				if season < SeasonMeta.SeasonType.SPRING or season > SeasonMeta.SeasonType.WINTER:
					errors.append("npc_schedule %s season %d invalid" % [schedule.id, season])
			for month: int in schedule.months:
				if month < 1 or month > CalendarManagerService.MONTHS_PER_YEAR:
					errors.append("npc_schedule %s month %d invalid" % [schedule.id, month])
			for weekday: int in schedule.weekdays:
				if weekday < 1 or weekday > 7:
					errors.append("npc_schedule %s weekday %d invalid" % [schedule.id, weekday])

	return errors


func _validate_item_dictionary(
	item_definitions: Dictionary[StringName, ItemMeta], errors: Array[String]
) -> Dictionary[StringName, ItemMeta]:
	var valid_items: Dictionary[StringName, ItemMeta] = {}
	for item_id: StringName in item_definitions:
		var item := item_definitions[item_id] as ItemMeta
		if item_id == &"":
			errors.append("items contains an empty key")
			continue
		if item == null:
			errors.append("items[%s] is null" % item_id)
			continue
		if item.id != item_id:
			errors.append("items[%s].id must match dictionary key, got %s" % [item_id, item.id])
			continue
		valid_items[item_id] = item
	return valid_items


func _validate_schedule_dictionary(
	schedule_definitions: Dictionary[StringName, Array], errors: Array[String]
) -> void:
	for schedule_id: StringName in schedule_definitions:
		var schedule_list: Array = schedule_definitions[schedule_id]
		if schedule_id == &"":
			errors.append("npc_schedules contains an empty key")
		elif schedule_list == null or schedule_list.is_empty():
			errors.append("npc_schedules[%s] is empty" % schedule_id)
		else:
			for schedule: NpcSchedule in schedule_list:
				if schedule == null:
					errors.append("npc_schedules[%s] contains null" % schedule_id)


func _validate_plant(plant: PlantMeta, item_ids: Dictionary, errors: Array[String]) -> void:
	if plant.stages.is_empty():
		errors.append("plant %s stages must not be empty" % plant.id)
	var previous_health: int = 0
	for index: int in plant.stages.size():
		var stage: HarvestableStage = plant.stages[index]
		if stage == null:
			errors.append("plant %s stages[%d] is null" % [plant.id, index])
			continue
		var min_health: int = stage.min_health
		if min_health <= previous_health:
			errors.append("plant %s stages[%d].min_health must increase" % [plant.id, index])
		previous_health = min_health
		if min_health <= 0:
			errors.append("plant %s stages[%d].min_health must be positive" % [plant.id, index])
		_validate_drops(stage.drops, "plant %s stages[%d]" % [plant.id, index], item_ids, errors)


func _validate_seed(seed_meta: SeedMeta, item_ids: Dictionary, errors: Array[String]) -> void:
	if seed_meta.item_type != ItemMeta.ItemType.SEED:
		errors.append("seed %s item_type must be SEED" % seed_meta.id)
	if seed_meta.plant_id == &"" or not item_ids.get(seed_meta.plant_id) is PlantMeta:
		errors.append("seed %s plant_id must reference PlantMeta %s" % [seed_meta.id, seed_meta.plant_id])


func _validate_tool(tool: ToolMeta, errors: Array[String]) -> void:
	if tool.item_type != ItemMeta.ItemType.TOOL:
		errors.append("tool %s item_type must be TOOL" % tool.id)
	if tool.event_id == &"":
		errors.append("tool %s event_id must not be empty" % tool.id)
	if tool.levels.is_empty():
		errors.append("tool %s levels must not be empty" % tool.id)
	for level: Resource in tool.levels:
		if level == null or not (level is ItemToolLevel or level is CellToolLevel):
			errors.append("tool %s levels contain invalid values" % tool.id)
		elif level is ItemToolLevel and (level.damage <= 0 or level.scale <= 0.0):
			errors.append("tool %s levels contain invalid values" % tool.id)
		elif level is CellToolLevel and (level.damage <= 0 or level.range.x <= 0 or level.range.y <= 0):
			errors.append("tool %s levels contain invalid values" % tool.id)


func _validate_harvestable(harvestable: HarvestableMeta, item_ids: Dictionary, errors: Array[String]) -> void:
	if harvestable.health <= 0:
		errors.append("harvestable %s health must be positive" % harvestable.id)
	if harvestable.depleted_replacement_id != &"":
		var replacement := item_ids.get(harvestable.depleted_replacement_id, null) as ItemMeta
		if not replacement is HarvestableMeta:
			errors.append(
				(
					"harvestable %s depleted_replacement_id must reference harvestable %s"
					% [harvestable.id, harvestable.depleted_replacement_id]
				)
			)
	if not harvestable is PlantMeta:
		if harvestable.stages.is_empty():
			errors.append("harvestable %s stages must not be empty" % harvestable.id)
		var thresholds: Dictionary[int, bool] = {}
		for index: int in harvestable.stages.size():
			var stage := harvestable.stages[index]
			if stage == null:
				errors.append("harvestable %s stages[%d] is null" % [harvestable.id, index])
				continue
			if stage.min_health > harvestable.health or thresholds.has(stage.min_health):
				errors.append("harvestable %s stages[%d].min_health invalid" % [harvestable.id, index])
			thresholds[stage.min_health] = true
			if stage.texture == null:
				errors.append("harvestable %s stages[%d].texture missing" % [harvestable.id, index])
			_validate_drops(stage.drops, "harvestable %s stages[%d]" % [harvestable.id, index], item_ids, errors)
		if not thresholds.has(1):
			errors.append("harvestable %s stages must cover health 1" % harvestable.id)


func _validate_drops(
	drops: Array[HarvestableDrop], owner_label: String, item_ids: Dictionary, errors: Array[String]
) -> void:
	for index: int in drops.size():
		var drop := drops[index]
		if drop == null:
			errors.append("%s drops[%d] is null" % [owner_label, index])
			continue
		if drop.item_id == &"" or not item_ids.has(drop.item_id):
			errors.append("%s drops[%d].item_id missing item %s" % [owner_label, index, drop.item_id])
		if drop.min_amount < 0 or drop.max_amount < drop.min_amount:
			errors.append("%s drops[%d] amount range invalid" % [owner_label, index])
		if drop.chance < 0.0 or drop.chance > 1.0:
			errors.append("%s drops[%d].chance invalid" % [owner_label, index])


func _count_meta_type(meta_script: Script) -> int:
	var count := 0
	for meta: ItemMeta in config.items.values():
		if is_instance_of(meta, meta_script):
			count += 1
	return count
