class_name ToolUseResult
extends ItemUseResult

var tool_kind: ToolMeta.ToolKind = ToolMeta.ToolKind.NONE
var skipped_reasons: Dictionary[Vector2i, StringName] = {}
var stamina_spent: int = 0
var projection_error: Error = OK
