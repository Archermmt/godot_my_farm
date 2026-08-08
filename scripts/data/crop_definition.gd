class_name CropDefinition
extends Resource

@export var id: StringName = &""
@export var seed_item_id: StringName = &""
@export var produce_item_id: StringName = &""
@export var stages: Array[GrowthStageDefinition] = []
@export var requires_water: bool = true
@export var harvest_tool: ItemDefinition.ToolKind = ItemDefinition.ToolKind.BASKET
@export var harvest_drop_table_id: StringName = &""


func mature_day() -> int:
	if stages.is_empty():
		return 0
	return stages[stages.size() - 1].start_day
