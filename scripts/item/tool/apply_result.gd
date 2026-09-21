class_name ApplyResult
extends RefCounted

var cells: Dictionary[Vector2i, CellState] = {}
var items: Dictionary[StringName, ItemState] = {}
var energy_spent: int = 0


func usable_cell_count() -> int:
	var count := 0
	for cell_state: CellState in cells.values():
		if cell_state != null and cell_state.usable and not cell_state.invalid:
			count += 1
	return count


func succeeded() -> bool:
	return not cells.is_empty() or not items.is_empty()
