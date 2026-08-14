class_name Plant
extends Harvestable

@onready var stage_visual: Sprite2D = get_node_or_null("StageVisual") as Sprite2D


func _ready() -> void:
	_refresh_stage_visual()


func bind_state(item_state: ItemState, item_meta: ItemMeta) -> Error:
	if not item_state is PlantState or not item_meta is PlantMeta:
		return ERR_INVALID_PARAMETER
	var bind_error := super.bind_state(item_state, item_meta)
	if bind_error != OK:
		return bind_error
	_refresh_stage_visual()
	return OK


func plant_state() -> PlantState:
	return state as PlantState


func plant_meta() -> PlantMeta:
	return meta as PlantMeta


func stage_index() -> int:
	var typed_state := plant_state()
	var typed_meta := plant_meta()
	if typed_state == null or typed_meta == null or typed_meta.stages.is_empty():
		return -1
	var result := 0
	for index: int in typed_meta.stages.size():
		if typed_state.growth_days >= typed_meta.stages[index].start_day:
			result = index
	return result


func is_mature() -> bool:
	var typed_meta := plant_meta()
	return stage_index() == typed_meta.stages.size() - 1 if typed_meta != null and not typed_meta.stages.is_empty() else false


func is_harvestable() -> bool:
	return is_mature()


func current_stage() -> PlantStage:
	var index := stage_index()
	var typed_meta := plant_meta()
	return typed_meta.stages[index] if typed_meta != null and index >= 0 else null


func grow_for_day(current_day: int) -> bool:
	var typed_state := plant_state()
	if typed_state == null or current_day <= 0 or typed_state.last_growth_day >= current_day:
		return false
	typed_state.last_growth_day = current_day
	typed_state.growth_days += 1
	_refresh_stage_visual()
	return true


func _refresh_stage_visual() -> void:
	if stage_visual == null:
		return
	var stage := current_stage()
	if stage == null:
		stage_visual.texture = null
		return
	stage_visual.texture = stage.texture
	stage_visual.position = stage.visual_offset
