class_name ApplyResult
extends RefCounted

var cells: Dictionary[Vector2i, CellState] = {}
var items: Dictionary[StringName, ItemState] = {}
var energy_spent: int = 0


func succeeded() -> bool:
	return not cells.is_empty() or not items.is_empty()
