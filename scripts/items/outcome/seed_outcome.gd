class_name SeedOutcome
extends RefCounted

var error: Error = OK
var effect_cells: Array[Vector2i] = []
var seed_item_id: StringName = &""


func succeeded() -> bool:
	return error == OK and not effect_cells.is_empty()


func effect_count() -> int:
	return effect_cells.size()


func consumed_count() -> int:
	return effect_cells.size()
