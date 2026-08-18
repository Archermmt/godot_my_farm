extends Node

func _ready() -> void:
	var catalog := DataCatalogService.new()
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


func _count_type(items: Dictionary[StringName, ItemMeta], meta_script: Script) -> int:
	var count := 0
	for item: ItemMeta in items.values():
		if is_instance_of(item, meta_script):
			count += 1
	return count
