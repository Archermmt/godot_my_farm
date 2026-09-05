class_name MapCell
extends RefCounted

var coordinates: Vector2i
var state: CellState


func _init(cell_coordinates: Vector2i = Vector2i.ZERO, next_state: CellState = null) -> void:
	coordinates = cell_coordinates
	state = next_state if next_state != null else CellState.new()
	state.cell = coordinates


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


func apply_tool(tool_kind: ToolMeta.ToolKind, commit: bool = true) -> bool:
	match tool_kind:
		ToolMeta.ToolKind.HOE:
			if not has_flag(CellState.CellFlag.BASE) or has_flag(CellState.CellFlag.BLOCKED):
				return false
			if not has_flag(CellState.CellFlag.DIGGABLE):
				return false
			if has_flag(CellState.CellFlag.DUG):
				return false
			if has_occupant():
				return false
			if commit:
				add_flag(CellState.CellFlag.DUG)
				if CalendarManager.check_weather([&"rain", &"storm"]):
					add_flag(CellState.CellFlag.WATERED)
			return true
		ToolMeta.ToolKind.WATERING_CAN:
			if has_flag(CellState.CellFlag.BLOCKED):
				return false
			if not has_flag(CellState.CellFlag.DUG):
				return false
			if has_flag(CellState.CellFlag.WATERED):
				return false
			if commit:
				add_flag(CellState.CellFlag.WATERED)
			return true
	return false


func has_occupant() -> bool:
	return not state.item_ids.is_empty()


func has_item(item_id: StringName) -> bool:
	return item_id in state.item_ids


func add_item_id(item_id: StringName) -> Error:
	if item_id == &"":
		return ERR_INVALID_PARAMETER
	if has_item(item_id):
		return ERR_ALREADY_EXISTS
	state.item_ids.append(item_id)
	return OK


func remove_item_id(item_id: StringName) -> Error:
	var index := state.item_ids.find(item_id)
	if index < 0:
		return ERR_DOES_NOT_EXIST
	state.item_ids.remove_at(index)
	return OK
