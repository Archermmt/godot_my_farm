class_name HarvestableMeta
extends ItemMeta

@export var required_tool: ToolMeta.ToolKind = ToolMeta.ToolKind.NONE
@export_range(1, 999, 1) var max_health: int = 1
@export var drops: Array[HarvestableDrop] = []
@export var depleted_replacement_id: StringName = &""
@export var blocks_movement: bool = true
@export var state_tags: Array[StringName] = []
@export var visual_stages: Array[HarvestableStage] = []
