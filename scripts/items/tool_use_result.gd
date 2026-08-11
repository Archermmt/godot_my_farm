class_name ToolUseResult
extends RefCounted

var error: Error = OK
var tool_kind: ToolMeta.ToolKind = ToolMeta.ToolKind.NONE
var changed_cells: Array[Vector2i] = []
var skipped_reasons: Dictionary[Vector2i, StringName] = {}
var stamina_spent: int = 0
var projection_error: Error = OK


func succeeded() -> bool:
	return error == OK and not changed_cells.is_empty()
