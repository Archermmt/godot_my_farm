class_name PlantMeta
extends HarvestableMeta

@export var seed_item_id: StringName = &""
@export var stages: Array[Dictionary] = []
@export var requires_water: bool = true


static func make_stage(
	start_day: int,
	max_health: int = 1,
	visual_key: StringName = &"",
	state_tags: Array[StringName] = [],
	drop_table_id: StringName = &""
) -> Dictionary:
	return {
		"start_day": start_day,
		"max_health": max_health,
		"visual_key": visual_key,
		"state_tags": state_tags.duplicate(),
		"drop_table_id": drop_table_id,
	}


static func _is_string_name_array(values: Array) -> bool:
	for value: Variant in values:
		if typeof(value) != TYPE_STRING_NAME:
			return false
	return true


static func is_stage_struct(stage: Dictionary) -> bool:
	return (
		typeof(stage.get("start_day")) == TYPE_INT
		and typeof(stage.get("max_health")) == TYPE_INT
		and typeof(stage.get("visual_key")) == TYPE_STRING_NAME
		and stage.get("state_tags") is Array
		and _is_string_name_array(stage.get("state_tags") as Array)
		and typeof(stage.get("drop_table_id")) == TYPE_STRING_NAME
	)


func mature_day() -> int:
	if stages.is_empty():
		return 0
	return int(stages[stages.size() - 1].get("start_day", 0))


func world_type() -> WorldType:
	return WorldType.PLANT
