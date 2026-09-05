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
	var definition: NpcSchedule = config.npc_schedules.get(id) as NpcSchedule
	if definition == null:
		push_error("[DataCatalog] unknown NPC schedule id: %s" % id)
	return definition


func has_item(id: StringName) -> bool:
	return config.items.has(id)


func validate() -> Array[String]:
	var item_definitions := config.items
	var schedule_definitions := config.npc_schedules
	var errors: Array[String] = []
	var item_ids := _validate_item_dictionary(item_definitions, errors)
	_validate_schedule_dictionary(schedule_definitions, errors)
	var schedule_npc_ids: Dictionary[StringName, StringName] = {}

	for item: ItemMeta in item_definitions.values():
		if item == null:
			continue
		if item.stack_limit <= 0:
			errors.append("item %s stack_limit must be positive" % item.id)
		if item.buy_price < 0:
			errors.append("item %s buy_price must be non-negative" % item.id)
		if item.sell_price < 0:
			errors.append("item %s sell_price must be non-negative" % item.id)
		if item is ToolMeta:
			_validate_tool(item as ToolMeta, errors)
		if item is SeedMeta:
			_validate_seed(item as SeedMeta, item_ids, errors)
		if item is PlantMeta:
			_validate_harvestable(item as PlantMeta, item_ids, errors)
			_validate_plant(item as PlantMeta, item_ids, errors)
		elif item is HarvestableMeta:
			_validate_harvestable(item as HarvestableMeta, item_ids, errors)

	for schedule: NpcSchedule in schedule_definitions.values():
		if schedule == null:
			continue
		if schedule.npc_id == &"":
			errors.append("npc_schedule %s npc_id must not be empty" % schedule.id)
		elif schedule_npc_ids.has(schedule.npc_id):
			errors.append(
				(
					"npc_schedule %s duplicates npc_id %s from %s"
					% [schedule.id, schedule.npc_id, schedule_npc_ids[schedule.npc_id]]
				)
			)
		else:
			schedule_npc_ids[schedule.npc_id] = schedule.id
		if schedule.fallback_map_id == &"":
			errors.append("npc_schedule %s fallback_map_id must not be empty" % schedule.id)
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
			for season: SeasonMeta.SeasonType in event.seasons:
				if season < SeasonMeta.SeasonType.SPRING or season > SeasonMeta.SeasonType.WINTER:
					errors.append("npc_schedule %s event %s season %d invalid" % [schedule.id, event.id, season])
			for month: int in event.months:
				if month < 1 or month > CalendarManagerService.MONTHS_PER_YEAR:
					errors.append("npc_schedule %s event %s month %d invalid" % [schedule.id, event.id, month])
			for weekday: int in event.weekdays:
				if weekday < 1 or weekday > 7:
					errors.append("npc_schedule %s event %s weekday %d invalid" % [schedule.id, event.id, weekday])
		for left_index: int in schedule.events.size():
			var left := schedule.events[left_index]
			if left == null:
				continue
			for right_index: int in range(left_index + 1, schedule.events.size()):
				var right := schedule.events[right_index]
				if right != null and left.priority == right.priority and _schedule_events_overlap(left, right):
					errors.append(
						(
							"npc_schedule %s events %s and %s overlap at priority %d"
							% [schedule.id, left.id, right.id, left.priority]
						)
					)

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
	schedule_definitions: Dictionary[StringName, NpcSchedule], errors: Array[String]
) -> void:
	for schedule_id: StringName in schedule_definitions:
		var schedule := schedule_definitions[schedule_id] as NpcSchedule
		if schedule_id == &"":
			errors.append("npc_schedules contains an empty key")
		elif schedule == null:
			errors.append("npc_schedules[%s] is null" % schedule_id)
		elif schedule.id != schedule_id:
			errors.append("npc_schedules[%s].id must match dictionary key, got %s" % [schedule_id, schedule.id])


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
	for level: ToolLevel in tool.levels:
		if level == null or level.damage <= 0 or level.effect_range.x <= 0 or level.effect_range.y <= 0:
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


func _schedule_events_overlap(left: NpcScheduleEvent, right: NpcScheduleEvent) -> bool:
	if not _filter_arrays_overlap(left.seasons, right.seasons):
		return false
	if not _filter_arrays_overlap(left.months, right.months):
		return false
	if not _filter_arrays_overlap(left.weekdays, right.weekdays):
		return false
	for left_range: Vector2i in _event_minute_ranges(left):
		for right_range: Vector2i in _event_minute_ranges(right):
			if maxi(left_range.x, right_range.x) < mini(left_range.y, right_range.y):
				return true
	return false


func _filter_arrays_overlap(left: Array, right: Array) -> bool:
	if left.is_empty() or right.is_empty():
		return true
	for value: Variant in left:
		if value in right:
			return true
	return false


func _event_minute_ranges(event: NpcScheduleEvent) -> Array[Vector2i]:
	var end_minute := event.start_minute + event.duration_minutes
	var ranges: Array[Vector2i] = [Vector2i(event.start_minute, mini(end_minute, 1440))]
	if end_minute > 1440:
		ranges.append(Vector2i(0, end_minute - 1440))
	return ranges


func _count_meta_type(meta_script: Script) -> int:
	var count := 0
	for meta: ItemMeta in config.items.values():
		if is_instance_of(meta, meta_script):
			count += 1
	return count
