class_name Plant
extends Harvestable

func _ready() -> void:
	super._ready()


func stage_definitions() -> Array[HarvestableStage]:
	var typed_meta := meta as PlantMeta
	return typed_meta.stages if typed_meta != null else []


func grow(current_day: int) -> bool:
	var typed_state := state as PlantState
	var typed_meta := meta as PlantMeta
	if (
		typed_state == null
		or typed_meta == null
		or current_day <= 0
		or typed_state.last_growth_day >= current_day
		or typed_state.health >= typed_meta.health
	):
		return false
	typed_state.last_growth_day = current_day
	typed_state.health = mini(typed_state.health + 1, typed_meta.health)
	refresh_stage_visual()
	return true
