class_name DataCatalogService
extends Node

const DEFAULT_CONFIG_PATH := "res://data/game_config.tres"

var config: GameConfig = load(DEFAULT_CONFIG_PATH) as GameConfig
var items: Dictionary[StringName, ItemMeta]:
	get:
		return config.items
var npc_schedules: Dictionary[StringName, NpcSchedule]:
	get:
		return config.npc_schedules
var dialogue_definitions: Dictionary[StringName, Resource]:
	get:
		return config.dialogue_definitions
var season_metas: Dictionary[StringName, SeasonMeta]:
	get:
		return config.season_metas
var audio_definitions: Dictionary[StringName, AudioDefinition]:
	get:
		return config.audio_definitions
var effect_definitions: Dictionary[StringName, EffectDefinition]:
	get:
		return config.effect_definitions
var weather_icons: Dictionary[StringName, Texture2D]:
	get:
		return config.weather_icons

var _validation_errors: Array[String] = []
var _ready_for_game: bool = false


func _ready() -> void:
	initialize()


func initialize(report_errors: bool = true) -> bool:
	_validation_errors.clear()
	_ready_for_game = false
	_validation_errors = validate_definitions(items, npc_schedules)
	_validate_dialogue_dictionary(dialogue_definitions, _validation_errors)
	if not _validation_errors.is_empty():
		_report_errors(report_errors)
		return false
	_ready_for_game = true
	if report_errors:
		print("[DataCatalog] ready | %s" % summary())
	return true


func is_ready_for_game() -> bool:
	return _ready_for_game


func validation_errors() -> Array[String]:
	return _validation_errors.duplicate()


func summary() -> String:
	return "items=%d plants=%d harvestables=%d schedules=%d" % [
		items.size(),
		_count_meta_type(PlantMeta),
		_count_meta_type(HarvestableMeta),
		npc_schedules.size(),
	]


func get_item(id: StringName) -> ItemMeta:
	var meta: ItemMeta = items.get(id) as ItemMeta
	if meta == null:
		push_error("[DataCatalog] unknown item id: %s" % id)
	return meta


func get_plant(id: StringName) -> PlantMeta:
	var meta: PlantMeta = items.get(id) as PlantMeta
	if meta == null:
		push_error("[DataCatalog] unknown plant id: %s" % id)
	return meta


func get_seed(id: StringName) -> SeedMeta:
	var meta: SeedMeta = items.get(id) as SeedMeta
	if meta == null:
		push_error("[DataCatalog] unknown seed id: %s" % id)
	return meta


func get_harvestable(id: StringName) -> HarvestableMeta:
	var meta: HarvestableMeta = items.get(id) as HarvestableMeta
	if meta == null:
		push_error("[DataCatalog] unknown harvestable id: %s" % id)
	return meta


func get_npc_schedule(id: StringName) -> NpcSchedule:
	var definition: NpcSchedule = npc_schedules.get(id) as NpcSchedule
	if definition == null:
		push_error("[DataCatalog] unknown NPC schedule id: %s" % id)
	return definition


func get_dialogue(id: StringName) -> Resource:
	return dialogue_definitions.get(id, null) as Resource


func has_item(id: StringName) -> bool:
	return items.has(id)


func item_count() -> int:
	return items.size()


static func validate_definitions(
	item_definitions: Dictionary[StringName, ItemMeta],
	schedule_definitions: Dictionary[StringName, NpcSchedule] = {}
) -> Array[String]:
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
			errors.append("npc_schedule %s duplicates npc_id %s from %s" % [schedule.id, schedule.npc_id, schedule_npc_ids[schedule.npc_id]])
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
			for season_id: StringName in event.seasons:
				if season_id not in CalendarState.SEASONS:
					errors.append("npc_schedule %s event %s season %s invalid" % [schedule.id, event.id, season_id])
			for month: int in event.months:
				if month < 1 or month > CalendarState.MONTHS_PER_YEAR:
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
					errors.append("npc_schedule %s events %s and %s overlap at priority %d" % [schedule.id, left.id, right.id, left.priority])

	return errors


static func _validate_item_dictionary(
	item_definitions: Dictionary[StringName, ItemMeta],
	errors: Array[String]
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


static func _validate_schedule_dictionary(
	schedule_definitions: Dictionary[StringName, NpcSchedule],
	errors: Array[String]
) -> void:
	for schedule_id: StringName in schedule_definitions:
		var schedule := schedule_definitions[schedule_id] as NpcSchedule
		if schedule_id == &"":
			errors.append("npc_schedules contains an empty key")
		elif schedule == null:
			errors.append("npc_schedules[%s] is null" % schedule_id)
		elif schedule.id != schedule_id:
			errors.append("npc_schedules[%s].id must match dictionary key, got %s" % [schedule_id, schedule.id])


static func _validate_dialogue_dictionary(
	definitions: Dictionary[StringName, Resource],
		errors: Array[String]
) -> void:
	for dialogue_id: StringName in definitions:
		var definition := definitions[dialogue_id] as Resource
		if dialogue_id == &"":
			errors.append("dialogue_definitions contains an empty key")
			continue
		if definition == null:
			errors.append("dialogue_definitions[%s] is null" % dialogue_id)
			continue
		if definition.id != dialogue_id:
			errors.append("dialogue_definitions[%s].id must match dictionary key" % dialogue_id)
		if definition.lines.is_empty():
			errors.append("dialogue %s must contain at least one line" % dialogue_id)
		for index: int in definition.lines.size():
			var line := definition.lines[index] as Resource
			if line == null or line.text.strip_edges().is_empty():
				errors.append("dialogue %s line %d must contain text" % [dialogue_id, index])


static func _validate_plant(plant: PlantMeta, item_ids: Dictionary, errors: Array[String]) -> void:
	if plant.stages.is_empty():
		errors.append("plant %s stages must not be empty" % plant.id)
	var previous_day: int = -1
	for index: int in plant.stages.size():
		var stage: PlantStage = plant.stages[index]
		if stage == null:
			errors.append("plant %s stages[%d] is null" % [plant.id, index])
			continue
		var start_day := stage.start_day
		var max_health := stage.max_health
		if start_day <= previous_day:
			errors.append("plant %s stages[%d].start_day must increase" % [plant.id, index])
		previous_day = start_day
		if max_health <= 0:
			errors.append("plant %s stages[%d].max_health must be positive" % [plant.id, index])
		_validate_drops(stage.drops, "plant %s stages[%d]" % [plant.id, index], item_ids, errors)


static func _validate_seed(seed: SeedMeta, item_ids: Dictionary, errors: Array[String]) -> void:
	if seed.item_type != ItemMeta.ItemType.SEED:
		errors.append("seed %s item_type must be SEED" % seed.id)
	if seed.plant_id == &"" or not item_ids.get(seed.plant_id) is PlantMeta:
		errors.append("seed %s plant_id must reference PlantMeta %s" % [seed.id, seed.plant_id])


static func _validate_tool(tool: ToolMeta, errors: Array[String]) -> void:
	if tool.item_type != ItemMeta.ItemType.TOOL:
		errors.append("tool %s item_type must be TOOL" % tool.id)
	if tool.charges_damage():
		if tool.damage_multipliers.is_empty():
			errors.append("tool %s damage_multipliers must not be empty" % tool.id)
		for multiplier: int in tool.damage_multipliers:
			if multiplier <= 0:
				errors.append("tool %s damage_multipliers must be positive" % tool.id)
	elif tool.charge_levels.is_empty():
		errors.append("tool %s charge_levels must not be empty" % tool.id)
	for dimensions: Vector2i in tool.charge_levels:
		if dimensions.x <= 0 or dimensions.y <= 0:
			errors.append("tool %s charge_levels dimensions must be positive" % tool.id)


static func _validate_harvestable(harvestable: HarvestableMeta, item_ids: Dictionary, errors: Array[String]) -> void:
	if harvestable.health <= 0:
		errors.append("harvestable %s health must be positive" % harvestable.id)
	_validate_drops(harvestable.drops, "harvestable %s" % harvestable.id, item_ids, errors)
	if harvestable.depleted_replacement_id != &"":
		var replacement := item_ids.get(harvestable.depleted_replacement_id, null) as ItemMeta
		if not replacement is HarvestableMeta:
			errors.append("harvestable %s depleted_replacement_id must reference harvestable %s" % [harvestable.id, harvestable.depleted_replacement_id])
	if not harvestable is PlantMeta:
		if harvestable.visual_stages.is_empty():
			errors.append("harvestable %s visual_stages must not be empty" % harvestable.id)
		var thresholds: Dictionary[int, bool] = {}
		for index: int in harvestable.visual_stages.size():
			var stage := harvestable.visual_stages[index]
			if stage == null:
				errors.append("harvestable %s visual_stages[%d] is null" % [harvestable.id, index])
				continue
			if stage.min_health > harvestable.health or thresholds.has(stage.min_health):
				errors.append("harvestable %s visual_stages[%d].min_health invalid" % [harvestable.id, index])
			thresholds[stage.min_health] = true
			if stage.texture == null:
				errors.append("harvestable %s visual_stages[%d].texture missing" % [harvestable.id, index])
		if not thresholds.has(1):
			errors.append("harvestable %s visual_stages must cover health 1" % harvestable.id)


static func _validate_drops(drops: Array[HarvestableDrop], owner: String, item_ids: Dictionary, errors: Array[String]) -> void:
	for index: int in drops.size():
		var drop := drops[index]
		if drop == null:
			errors.append("%s drops[%d] is null" % [owner, index])
			continue
		if drop.item_id == &"" or not item_ids.has(drop.item_id):
			errors.append("%s drops[%d].item_id missing item %s" % [owner, index, drop.item_id])
		if drop.min_amount < 0 or drop.max_amount < drop.min_amount:
			errors.append("%s drops[%d] amount range invalid" % [owner, index])
		if drop.chance < 0.0 or drop.chance > 1.0:
			errors.append("%s drops[%d].chance invalid" % [owner, index])


static func _schedule_events_overlap(left: NpcScheduleEvent, right: NpcScheduleEvent) -> bool:
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


static func _event_minute_ranges(event: NpcScheduleEvent) -> Array[Vector2i]:
	var end_minute := event.start_minute + event.duration_minutes
	var ranges: Array[Vector2i] = [Vector2i(event.start_minute, mini(end_minute, 1440))]
	if end_minute > 1440:
		ranges.append(Vector2i(0, end_minute - 1440))
	return ranges


static func _filter_arrays_overlap(left: Array, right: Array) -> bool:
	if left.is_empty() or right.is_empty():
		return true
	for value: Variant in left:
		if value in right:
			return true
	return false


func _count_meta_type(meta_script: Script) -> int:
	var count := 0
	for meta: ItemMeta in items.values():
		if is_instance_of(meta, meta_script):
			count += 1
	return count


func _report_errors(enabled: bool) -> void:
	if not enabled:
		return
	for error: String in _validation_errors:
		push_error("[DataCatalog] %s" % error)
