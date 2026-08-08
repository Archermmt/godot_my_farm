class_name DataCatalogService
extends Node

const CORE_CATALOG_PATH := "res://data/catalogs/core_catalog.tres"

var _catalog: GameCatalog = null
var _validation_errors: Array[String] = []
var _items: Dictionary[StringName, ItemDefinition] = {}
var _crops: Dictionary[StringName, CropDefinition] = {}
var _harvestables: Dictionary[StringName, HarvestableDefinition] = {}
var _drop_tables: Dictionary[StringName, DropTable] = {}
var _npc_schedules: Dictionary[StringName, NpcSchedule] = {}
var _ready_for_game: bool = false


func _ready() -> void:
	load_catalog(CORE_CATALOG_PATH)


func load_catalog(path: String, report_errors: bool = true) -> bool:
	var resource: Resource = load(path)
	var loaded_catalog: GameCatalog = resource as GameCatalog
	if loaded_catalog == null:
		_clear()
		_validation_errors = ["catalog path %s did not load a GameCatalog" % path]
		_report_errors(report_errors)
		return false
	return initialize_from_catalog(loaded_catalog, report_errors)


func initialize_from_catalog(catalog: GameCatalog, report_errors: bool = true) -> bool:
	_clear()
	_catalog = catalog
	_validation_errors = CatalogValidator.validate(catalog)
	if not _validation_errors.is_empty():
		_report_errors(report_errors)
		return false
	for item: ItemDefinition in catalog.items:
		_items[item.id] = item
	for crop: CropDefinition in catalog.crops:
		_crops[crop.id] = crop
	for harvestable: HarvestableDefinition in catalog.harvestables:
		_harvestables[harvestable.id] = harvestable
	for table: DropTable in catalog.drop_tables:
		_drop_tables[table.id] = table
	for schedule: NpcSchedule in catalog.npc_schedules:
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
	return "items=%d crops=%d harvestables=%d drops=%d schedules=%d" % [
		_items.size(),
		_crops.size(),
		_harvestables.size(),
		_drop_tables.size(),
		_npc_schedules.size(),
	]


func get_item(id: StringName) -> ItemDefinition:
	var definition: ItemDefinition = _items.get(id) as ItemDefinition
	if definition == null:
		push_error("[DataCatalog] unknown item id: %s" % id)
	return definition


func get_crop(id: StringName) -> CropDefinition:
	var definition: CropDefinition = _crops.get(id) as CropDefinition
	if definition == null:
		push_error("[DataCatalog] unknown crop id: %s" % id)
	return definition


func get_harvestable(id: StringName) -> HarvestableDefinition:
	var definition: HarvestableDefinition = _harvestables.get(id) as HarvestableDefinition
	if definition == null:
		push_error("[DataCatalog] unknown harvestable id: %s" % id)
	return definition


func get_drop_table(id: StringName) -> DropTable:
	var definition: DropTable = _drop_tables.get(id) as DropTable
	if definition == null:
		push_error("[DataCatalog] unknown drop table id: %s" % id)
	return definition


func get_npc_schedule(id: StringName) -> NpcSchedule:
	var definition: NpcSchedule = _npc_schedules.get(id) as NpcSchedule
	if definition == null:
		push_error("[DataCatalog] unknown NPC schedule id: %s" % id)
	return definition


func has_item(id: StringName) -> bool:
	return _items.has(id)


func has_crop(id: StringName) -> bool:
	return _crops.has(id)


func item_count() -> int:
	return _items.size()


func _clear() -> void:
	_catalog = null
	_validation_errors.clear()
	_items.clear()
	_crops.clear()
	_harvestables.clear()
	_drop_tables.clear()
	_npc_schedules.clear()
	_ready_for_game = false


func _report_errors(enabled: bool) -> void:
	if not enabled:
		return
	for error: String in _validation_errors:
		push_error("[DataCatalog] %s" % error)
