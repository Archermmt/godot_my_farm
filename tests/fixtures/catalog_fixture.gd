extends Node

const CATALOG_PATH := "res://data/catalogs/core_catalog.tres"


func _ready() -> void:
	var catalog: GameCatalog = load(CATALOG_PATH) as GameCatalog
	if catalog == null:
		push_error("[T01Fixture] failed to load %s" % CATALOG_PATH)
		get_tree().quit(1)
		return
	var errors: Array[String] = CatalogValidator.validate(catalog)
	if not errors.is_empty():
		for error: String in errors:
			push_error("[T01Fixture] %s" % error)
		get_tree().quit(1)
		return
	print("[T01Fixture] catalog valid | items=%d plants=%d harvestables=%d drops=%d schedules=%d" % [
		catalog.items.size(),
		_count_type(catalog.items, PlantMeta),
		_count_type(catalog.items, HarvestableMeta),
		catalog.drop_tables.size(),
		catalog.npc_schedules.size(),
	])
	get_tree().quit(0)


func _count_type(items: Array[ItemMeta], meta_script: Script) -> int:
	var count := 0
	for item: ItemMeta in items:
		if is_instance_of(item, meta_script):
			count += 1
	return count
