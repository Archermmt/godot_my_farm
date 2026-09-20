class_name MapCell
extends RefCounted

var state: CellState = CellState.new()
var coord: Vector2i:
	get:
		return state.coord if state != null else Vector2i.ZERO


func from_state(next_state: CellState) -> Error:
	if next_state == null:
		return ERR_INVALID_PARAMETER
	state = next_state
	return OK


func to_state() -> CellState:
	return state


func add_flag(value: CellState.CellFlag) -> void:
	state.flags |= value


func remove_flag(value: CellState.CellFlag) -> void:
	state.flags &= ~value


func has_flag(value: CellState.CellFlag) -> bool:
	return (state.flags & value) == value


func has_all_flags(values: Array[CellState.CellFlag]) -> bool:
	for value: CellState.CellFlag in values:
		if not has_flag(value):
			return false
	return true
