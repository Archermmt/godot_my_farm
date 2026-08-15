extends Node

const DATA_CATALOG_SCENE := "res://scenes/autoload/data_catalog.tscn"


func _ready() -> void:
	var packed := load(DATA_CATALOG_SCENE) as PackedScene
	var catalog := packed.instantiate() as DataCatalogService if packed != null else null
	if catalog == null:
		push_error("[T01Fixture] failed to load %s" % DATA_CATALOG_SCENE)
		get_tree().quit(1)
		return
	var errors := DataCatalogService.validate_definitions(catalog.items, catalog.npc_schedules)
	if not errors.is_empty():
		for error: String in errors:
			push_error("[T01Fixture] %s" % error)
		get_tree().quit(1)
		return
	print("[T01Fixture] catalog valid | items=%d plants=%d harvestables=%d schedules=%d" % [
		catalog.items.size(),
		_count_type(catalog.items, PlantMeta),
		_count_type(catalog.items, HarvestableMeta),
		catalog.npc_schedules.size(),
	])
	catalog.free()
	get_tree().quit(0)


func _count_type(items: Array[ItemMeta], meta_script: Script) -> int:
	var count := 0
	for item: ItemMeta in items:
		if is_instance_of(item, meta_script):
			count += 1
	return count
