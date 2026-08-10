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
	if typed_state == null:
		GameManager.debug("[PlantGrowth] plant=%s skipped=no_state day=%d" % [item_id(), current_day])
		return false
	if typed_meta == null:
		GameManager.debug("[PlantGrowth] plant=%s skipped=no_meta day=%d" % [item_id(), current_day])
		return false
	if current_day <= 0:
		GameManager.debug("[PlantGrowth] plant=%s skipped=invalid_day day=%d" % [item_id(), current_day])
		return false
	if typed_state.last_growth_day >= current_day:
		GameManager.debug(
			"[PlantGrowth] plant=%s skipped=already_grew day=%d last_growth_day=%d"
			% [item_id(), current_day, typed_state.last_growth_day]
		)
		return false
	if typed_state.health >= typed_meta.health:
		GameManager.debug(
			"[PlantGrowth] plant=%s skipped=mature day=%d health=%d max_health=%d"
			% [item_id(), current_day, typed_state.health, typed_meta.health]
		)
		return false
	typed_state.last_growth_day = current_day
	typed_state.health = mini(typed_state.health + 1, typed_meta.health)
	refresh_stage_visual()
	return true
