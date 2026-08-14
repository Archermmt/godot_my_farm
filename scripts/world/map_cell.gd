class_name MapCell
extends RefCounted

var coordinates: Vector2i
var static_flags: int = 0
var _state: CellState


func _init(cell_coordinates: Vector2i = Vector2i.ZERO, initial_static_flags: int = 0) -> void:
	coordinates = cell_coordinates
	static_flags = initial_static_flags
	_state = CellState.new()
	_state.cell = coordinates


func add_static_flag(value: CellState.CellFlag) -> void:
	static_flags |= value


func remove_static_flag(value: CellState.CellFlag) -> void:
	static_flags &= ~value


func has_static_flag(value: CellState.CellFlag) -> bool:
	return (static_flags & value) == value


func state_flags() -> int:
	return _state.flags


func set_state_flags(value: int) -> void:
	_state.flags = value


func add_state_flag(value: CellState.CellFlag) -> void:
	_state.flags |= value


func remove_state_flag(value: CellState.CellFlag) -> void:
	_state.flags &= ~value


func has_state_flag(value: CellState.CellFlag) -> bool:
	return (_state.flags & value) == value


func is_walkable() -> bool:
	return has_static_flag(CellState.CellFlag.BASE) and not has_static_flag(CellState.CellFlag.BLOCKED)


func is_diggable() -> bool:
	return has_static_flag(CellState.CellFlag.DIGGABLE) and not has_static_flag(CellState.CellFlag.BLOCKED)


func is_dropable() -> bool:
	return has_static_flag(CellState.CellFlag.DROPABLE) and not has_static_flag(CellState.CellFlag.BLOCKED)


func is_dug() -> bool:
	return has_state_flag(CellState.CellFlag.DUG)


func is_watered() -> bool:
	return has_state_flag(CellState.CellFlag.WATERED)


func tool_rejection_reason(tool_kind: ToolMeta.ToolKind) -> StringName:
	match tool_kind:
		ToolMeta.ToolKind.HOE:
			if has_static_flag(CellState.CellFlag.BLOCKED):
				return &"blocked"
			if not has_static_flag(CellState.CellFlag.DIGGABLE):
				return &"not_diggable"
			if is_dug():
				return &"already_dug"
			if has_occupant():
				return &"occupied"
			return &""
		ToolMeta.ToolKind.WATERING_CAN:
			if has_static_flag(CellState.CellFlag.BLOCKED):
				return &"blocked"
			if not is_dug():
				return &"not_dug"
			if is_watered():
				return &"already_watered"
			return &""
	return &"unsupported_tool"


func use_tool(tool_kind: ToolMeta.ToolKind) -> Error:
	if tool_rejection_reason(tool_kind) != &"":
		return ERR_UNAVAILABLE
	match tool_kind:
		ToolMeta.ToolKind.HOE:
			add_state_flag(CellState.CellFlag.DUG)
		ToolMeta.ToolKind.WATERING_CAN:
			add_state_flag(CellState.CellFlag.WATERED)
		_:
			return ERR_UNAVAILABLE
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
	_state = cell_state
	return OK


func cell_state() -> CellState:
	return _state
