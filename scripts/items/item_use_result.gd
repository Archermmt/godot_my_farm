class_name ItemUseResult
extends RefCounted

var error: Error = OK
var effect_cells: Array[Vector2i] = []


func succeeded() -> bool:
	return error == OK and not effect_cells.is_empty()


func effect_count() -> int:
	return effect_cells.size()
