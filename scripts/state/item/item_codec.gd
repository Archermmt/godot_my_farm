class_name ItemCodec
extends RefCounted

const STATE_SCRIPTS: Dictionary[String, Script] = {
	"item": preload("res://scripts/state/item/item_state.gd"),
	"harvestable": preload("res://scripts/state/item/harvestable_state.gd"),
	"plant": preload("res://scripts/state/item/plant_state.gd"),
}


static func to_dict(state: ItemState) -> Dictionary:
	return state.to_dict_impl() if state != null else {}


static func from_dict(data: Dictionary) -> ItemState:
	if not SerializationUtil.has_valid_string(data, "state_type"):
		return null
	var state_script := STATE_SCRIPTS.get(String(data.get("state_type", "")), null) as Script
	if state_script == null:
		return null
	var restored := state_script.new() as ItemState
	return restored if restored != null and restored.from_dict_impl(data) else null
