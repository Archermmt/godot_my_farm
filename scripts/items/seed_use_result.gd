class_name SeedUseResult
extends ItemUseResult

var seed_item_id: StringName = &""
var instance_ids: Array[StringName] = []

func consumed_count() -> int:
	return effect_cells.size()
