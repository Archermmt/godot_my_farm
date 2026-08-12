class_name PlantItem
extends HarvestableItem

var plant_state: PlantState = null
var plant_meta: PlantMeta = null

@onready var stage_visual: Sprite2D = get_node_or_null("StageVisual") as Sprite2D


func _ready() -> void:
	_refresh_stage_visual()


func bind_state(item_state: ItemState, item_meta: ItemMeta) -> Error:
	if not item_state is PlantState or not item_meta is PlantMeta:
		return ERR_INVALID_PARAMETER
	var bind_error := super.bind_state(item_state, item_meta)
	if bind_error != OK:
		return bind_error
	plant_state = item_state as PlantState
	plant_meta = item_meta as PlantMeta
	_refresh_stage_visual()
	return OK


func stage_index() -> int:
	if plant_meta == null or plant_meta.stages.is_empty():
		return -1
	var result := 0
	for index: int in plant_meta.stages.size():
		if plant_state.growth_days >= plant_meta.stages[index].start_day:
			result = index
	return result


func is_mature() -> bool:
	return stage_index() == plant_meta.stages.size() - 1 if plant_meta != null and not plant_meta.stages.is_empty() else false


func is_harvestable() -> bool:
	return is_mature()


func current_stage() -> PlantStageMeta:
	var index := stage_index()
	return plant_meta.stages[index] if plant_meta != null and index >= 0 else null


func grow_for_day(current_day: int) -> bool:
	if plant_state == null or current_day <= 0 or plant_state.last_growth_day >= current_day:
		return false
	plant_state.last_growth_day = current_day
	plant_state.growth_days += 1
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
