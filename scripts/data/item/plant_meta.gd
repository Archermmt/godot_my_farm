class_name PlantMeta
extends HarvestableMeta

@export var seed_item_id: StringName = &""
@export var stages: Array[PlantStageMeta] = []
@export var requires_water: bool = true


static func make_stage(
	start_day: int,
	max_health: int = 1,
	texture: Texture2D = null,
	state_tags: Array[StringName] = [],
	drop_table_id: StringName = &"",
	visual_offset: Vector2 = Vector2(0, -5)
) -> PlantStageMeta:
	var stage := PlantStageMeta.new()
	stage.start_day = start_day
	stage.max_health = max_health
	stage.texture = texture
	stage.visual_offset = visual_offset
	stage.state_tags = state_tags.duplicate()
	stage.drop_table_id = drop_table_id
	return stage


func mature_day() -> int:
	if stages.is_empty():
		return 0
	return stages[stages.size() - 1].start_day


func world_type() -> WorldType:
	return WorldType.PLANT
