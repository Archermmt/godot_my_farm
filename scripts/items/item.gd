class_name Item
extends Node2D

var state: ItemState = null
var meta: ItemMeta = null


func bind_state(item_state: ItemState, item_meta: ItemMeta) -> Error:
	if item_state == null or item_meta == null or item_state.instance_id == &"" or item_state.meta_id != item_meta.id:
		return ERR_INVALID_PARAMETER
	state = item_state
	meta = item_meta
	return OK


func item_id() -> StringName:
	return state.instance_id if state != null else &""
