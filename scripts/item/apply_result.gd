class_name ApplyResult
extends RefCounted

var cells: Array[Vector2i] = []
var items: Dictionary[StringName, ItemState] = {}


func succeeded() -> bool:
	return not cells.is_empty() or not items.is_empty()
