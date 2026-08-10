class_name MapCell
extends RefCounted

var coordinates: Vector2i
var _state: CellState


func _init(cell_coordinates: Vector2i = Vector2i.ZERO, initial_flags: int = 0) -> void:
	coordinates = cell_coordinates
	_state = CellState.new()
	_state.cell = coordinates
	_state.flags = initial_flags


func flags() -> int:
	return _state.flags


func set_flags(value: int) -> void:
	_state.flags = value


func add_flag(value: CellState.CellFlag) -> void:
	_state.flags |= value


func remove_flag(value: CellState.CellFlag) -> void:
	_state.flags &= ~value


func has_flag(value: CellState.CellFlag) -> bool:
	return (_state.flags & value) == value


func is_walkable() -> bool:
	return has_flag(CellState.CellFlag.BASE) and not has_flag(CellState.CellFlag.BLOCKED)


func is_diggable() -> bool:
	return has_flag(CellState.CellFlag.DIGGABLE) and not has_flag(CellState.CellFlag.BLOCKED)


func is_dropable() -> bool:
	return has_flag(CellState.CellFlag.DROPABLE) and not has_flag(CellState.CellFlag.BLOCKED)


func is_dug() -> bool:
	return has_flag(CellState.CellFlag.DUG)


func is_watered() -> bool:
	return has_flag(CellState.CellFlag.WATERED)


func can_till() -> bool:
	return is_diggable() and not is_dug() and not has_occupant()


func can_water() -> bool:
	return is_diggable() and is_dug()


func can_drop() -> bool:
	return is_dropable() and not has_occupant()


func dig() -> Error:
	if not can_till():
		return ERR_UNAVAILABLE
	add_flag(CellState.CellFlag.DUG)
	return OK


func water() -> Error:
	if not can_water():
		return ERR_UNAVAILABLE
	add_flag(CellState.CellFlag.WATERED)
	return OK


func has_occupant() -> bool:
	return not _state.item_ids.is_empty()


func has_item(item_id: StringName) -> bool:
	return item_id in _state.item_ids


func add_item_id(item_id: StringName) -> Error:
	if item_id == &"":
		return ERR_INVALID_PARAMETER
	if has_item(item_id):
		return ERR_ALREADY_EXISTS
	_state.item_ids.append(item_id)
	return OK


func remove_item_id(item_id: StringName) -> Error:
	var index := _state.item_ids.find(item_id)
	if index < 0:
		return ERR_DOES_NOT_EXIST
	_state.item_ids.remove_at(index)
	return OK


func bind_state(cell_state: CellState) -> Error:
	if cell_state == null or cell_state.cell != coordinates:
		return ERR_INVALID_PARAMETER
	var static_flags := flags() & ~(CellState.CellFlag.DUG | CellState.CellFlag.WATERED)
	var dynamic_flags := cell_state.flags & (CellState.CellFlag.DUG | CellState.CellFlag.WATERED)
	cell_state.flags = static_flags | dynamic_flags
	_state = cell_state
	return OK


func cell_state() -> CellState:
	return _state
