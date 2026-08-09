class_name MapCell
extends RefCounted

enum Status {
	BASE = 1,
	DIGGABLE = 2,
	DROPABLE = 4,
	ROAD = 8,
	BLOCKED = 16,
	RESOURCE = 32,
	INTERIOR = 64,
}

var coordinates: Vector2i
var _state: CellState


func _init(cell_coordinates: Vector2i = Vector2i.ZERO, initial_status: int = 0) -> void:
	coordinates = cell_coordinates
	_state = CellState.new()
	_state.cell = coordinates
	_state.status = initial_status


func status() -> int:
	return _state.status


func set_status(value: int) -> void:
	_state.status = value


func add_status(value: Status) -> void:
	_state.status |= value


func remove_status(value: Status) -> void:
	_state.status &= ~value


func has_status(value: Status) -> bool:
	return (_state.status & value) == value


func is_walkable() -> bool:
	return has_status(Status.BASE) and not has_status(Status.BLOCKED)


func is_diggable() -> bool:
	return has_status(Status.DIGGABLE) and not has_status(Status.BLOCKED)


func is_dropable() -> bool:
	return has_status(Status.DROPABLE) and not has_status(Status.BLOCKED)


func is_dug() -> bool:
	return _state.dug


func is_watered(current_day: int) -> bool:
	return _state.is_watered(current_day)


func can_till() -> bool:
	return is_diggable() and not is_dug() and not has_occupant()


func can_water() -> bool:
	return is_diggable() and is_dug()


func can_drop() -> bool:
	return is_dropable() and not has_occupant()


func dig() -> Error:
	if not can_till():
		return ERR_UNAVAILABLE
	_state.dug = true
	return OK


func water(current_day: int) -> Error:
	if current_day < 0:
		return ERR_INVALID_PARAMETER
	if not can_water():
		return ERR_UNAVAILABLE
	_state.watered_on_day = current_day
	return OK


func has_occupant() -> bool:
	return _state.has_entities()


func bind_state(state: CellState) -> Error:
	if state == null or state.cell != coordinates:
		return ERR_INVALID_PARAMETER
	state.status = status()
	_state = state
	return OK


func cell_state() -> CellState:
	return _state
