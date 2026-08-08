class_name GrowthStageDefinition
extends Resource

@export_range(0, 999, 1) var start_day: int = 0
@export_range(1, 999, 1) var max_health: int = 1
@export var visual_key: StringName = &""
@export var state_tags: Array[StringName] = []
@export var drop_table_id: StringName = &""


func duplicate_stage() -> GrowthStageDefinition:
	var stage := GrowthStageDefinition.new()
	stage.start_day = start_day
	stage.max_health = max_health
	stage.visual_key = visual_key
	stage.state_tags = state_tags.duplicate()
	stage.drop_table_id = drop_table_id
	return stage
