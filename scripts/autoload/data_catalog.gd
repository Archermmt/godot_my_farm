class_name DataCatalogService
extends Node

const CORE_CATALOG_PATH := "res://data/catalogs/core_catalog.tres"

var _catalog: GameCatalog = null
var _validation_errors: Array[String] = []
var _items: Dictionary[StringName, ItemMeta] = {}
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
	for item: ItemMeta in catalog.items:
		_items[item.id] = item
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
	return "items=%d plants=%d harvestables=%d drops=%d schedules=%d" % [
		_items.size(),
		_count_meta_type(PlantMeta),
		_count_meta_type(HarvestableMeta),
		_drop_tables.size(),
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


func get_harvestable(id: StringName) -> HarvestableMeta:
	var meta: HarvestableMeta = _items.get(id) as HarvestableMeta
	if meta == null:
		push_error("[DataCatalog] unknown harvestable id: %s" % id)
	return meta


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


func item_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_items.keys())
	return ids


func has_plant(id: StringName) -> bool:
	return _items.get(id) is PlantMeta


func item_count() -> int:
	return _items.size()


func _clear() -> void:
	_catalog = null
	_validation_errors.clear()
	_items.clear()
	_drop_tables.clear()
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
