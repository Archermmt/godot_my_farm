class_name ToolOutcome
extends RefCounted

var error: Error = OK
var effect_cells: Array[Vector2i] = []
var tool_kind: ToolMeta.ToolKind = ToolMeta.ToolKind.NONE
var skipped_reasons: Dictionary[Vector2i, StringName] = {}
var energy_spent: int = 0


func succeeded() -> bool:
	return error == OK and not effect_cells.is_empty()


func effect_count() -> int:
	return effect_cells.size()
