class_name HarvestableDefinition
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var required_tool: ItemDefinition.ToolKind = ItemDefinition.ToolKind.NONE
@export_range(1, 999, 1) var max_health: int = 1
@export var drop_table_id: StringName = &""
@export var blocks_movement: bool = true
@export var state_tags: Array[StringName] = []
