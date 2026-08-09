class_name Entity
extends Node2D

@export var type: EntityState.EntityType = EntityState.EntityType.GENERIC
var state: EntityState = null


func bind_state(entity_state: EntityState) -> Error:
	if entity_state == null or entity_state.instance_id == &"":
		return ERR_INVALID_PARAMETER
	state = entity_state
	type = entity_state.type
	return OK


func entity_id() -> StringName:
	return state.instance_id if state != null else &""
