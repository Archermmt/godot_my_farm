class_name Plant
extends Harvestable

func _ready() -> void:
	super._ready()
	refresh_stage_visual()


func get_state() -> PlantState:
	return super.get_state() as PlantState


func get_meta() -> PlantMeta:
	return super.get_meta() as PlantMeta


func stage_index() -> int:
	var typed_state := get_state()
	var typed_meta := get_meta() as PlantMeta
	if typed_state == null or typed_meta == null or typed_meta.stages.is_empty():
		return -1
	var result := 0
	for index: int in typed_meta.stages.size():
		if typed_state.growth_days >= typed_meta.stages[index].start_day:
			result = index
	return result


func is_mature() -> bool:
	var typed_meta := get_meta() as PlantMeta
	return stage_index() == typed_meta.stages.size() - 1 if typed_meta != null and not typed_meta.stages.is_empty() else false


func current_stage() -> PlantStage:
	var index := stage_index()
	var typed_meta := get_meta() as PlantMeta
	return typed_meta.stages[index] if typed_meta != null and index >= 0 else null


func grow_for_day(current_day: int) -> bool:
	var typed_state := get_state()
	if typed_state == null or current_day <= 0 or typed_state.last_growth_day >= current_day:
		return false
	typed_state.last_growth_day = current_day
	typed_state.growth_days += 1
	refresh_stage_visual()
	return true


func refresh_stage_visual() -> void:
	var stage := current_stage()
	refresh_visual(stage.texture if stage != null else null, stage.visual_offset if stage != null else Vector2.ZERO)
