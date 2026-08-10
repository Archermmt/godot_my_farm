class_name HarvestableMeta
extends ItemMeta

@export var required_tool: ToolMeta.ToolKind = ToolMeta.ToolKind.NONE
@export_range(1, 999, 1) var max_health: int = 1
@export var drop_table_id: StringName = &""
@export var blocks_movement: bool = true
@export var state_tags: Array[StringName] = []


func world_type() -> WorldType:
	return WorldType.HARVESTABLE
