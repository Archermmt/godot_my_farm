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
	print("[T01Fixture] catalog valid | items=%d crops=%d harvestables=%d drops=%d schedules=%d" % [
		catalog.items.size(),
		catalog.crops.size(),
		catalog.harvestables.size(),
		catalog.drop_tables.size(),
		catalog.npc_schedules.size(),
	])
	get_tree().quit(0)
