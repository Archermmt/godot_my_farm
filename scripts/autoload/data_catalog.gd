class_name DataCatalogService
extends Node

@export_category("Definitions")
@export var items: Array[ItemMeta] = []
@export var npc_schedules: Array[NpcSchedule] = []

var _validation_errors: Array[String] = []
var _items: Dictionary[StringName, ItemMeta] = {}
var _npc_schedules: Dictionary[StringName, NpcSchedule] = {}
var _ready_for_game: bool = false


func _ready() -> void:
	initialize()


func initialize(report_errors: bool = true) -> bool:
	return initialize_from_definitions(items, npc_schedules, report_errors)


func initialize_from_definitions(
	item_definitions: Array[ItemMeta],
	schedule_definitions: Array[NpcSchedule] = [],
	report_errors: bool = true
) -> bool:
	_clear()
	_validation_errors = validate_definitions(item_definitions, schedule_definitions)
	if not _validation_errors.is_empty():
		_report_errors(report_errors)
		return false
	for item: ItemMeta in item_definitions:
		_items[item.id] = item
	for schedule: NpcSchedule in schedule_definitions:
		_npc_schedules[schedule.id] = schedule
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
		_items.size(),
		_count_meta_type(PlantMeta),
		_count_meta_type(HarvestableMeta),
		_npc_schedules.size(),
	]


func get_item(id: StringName) -> ItemMeta:
	var meta: ItemMeta = _items.get(id) as ItemMeta
	if meta == null:
		push_error("[DataCatalog] unknown item id: %s" % id)
	return meta


func get_plant(id: StringName) -> PlantMeta:
	var meta: PlantMeta = _items.get(id) as PlantMeta
	if meta == null:
		push_error("[DataCatalog] unknown plant id: %s" % id)
	return meta


func get_seed(id: StringName) -> SeedMeta:
	var meta: SeedMeta = _items.get(id) as SeedMeta
	if meta == null:
		push_error("[DataCatalog] unknown seed id: %s" % id)
	return meta


func get_harvestable(id: StringName) -> HarvestableMeta:
	var meta: HarvestableMeta = _items.get(id) as HarvestableMeta
	if meta == null:
		push_error("[DataCatalog] unknown harvestable id: %s" % id)
	return meta


func get_npc_schedule(id: StringName) -> NpcSchedule:
	var definition: NpcSchedule = _npc_schedules.get(id) as NpcSchedule
	if definition == null:
		push_error("[DataCatalog] unknown NPC schedule id: %s" % id)
	return definition


func has_item(id: StringName) -> bool:
	return _items.has(id)


func item_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_items.keys())
	return ids


func has_plant(id: StringName) -> bool:
	return _items.get(id) is PlantMeta


func item_count() -> int:
	return _items.size()


static func validate_definitions(
	item_definitions: Array[ItemMeta],
	schedule_definitions: Array[NpcSchedule] = []
) -> Array[String]:
	var errors: Array[String] = []
	var item_ids := _collect_ids(item_definitions, "item", errors)
	_collect_ids(schedule_definitions, "npc_schedule", errors)

	for item: ItemMeta in item_definitions:
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
		if item is SeedMeta:
			_validate_seed(item as SeedMeta, item_ids, errors)
		if item is PlantMeta:
			_validate_harvestable(item as PlantMeta, item_ids, errors)
			_validate_plant(item as PlantMeta, item_ids, errors)
		elif item is HarvestableMeta:
			_validate_harvestable(item as HarvestableMeta, item_ids, errors)

	for schedule: NpcSchedule in schedule_definitions:
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


static func _validate_harvestable(harvestable: HarvestableMeta, item_ids: Dictionary, errors: Array[String]) -> void:
	if harvestable.max_health <= 0:
		errors.append("harvestable %s max_health must be positive" % harvestable.id)
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
			if stage.min_health > harvestable.max_health or thresholds.has(stage.min_health):
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


func _clear() -> void:
	_validation_errors.clear()
	_items.clear()
	_npc_schedules.clear()
	_ready_for_game = false


func _count_meta_type(meta_script: Script) -> int:
	var count := 0
	for meta: ItemMeta in _items.values():
		if is_instance_of(meta, meta_script):
			count += 1
	return count


func _report_errors(enabled: bool) -> void:
	if not enabled:
		return
	for error: String in _validation_errors:
		push_error("[DataCatalog] %s" % error)
