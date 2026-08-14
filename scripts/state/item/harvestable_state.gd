class_name HarvestableState
extends ItemState

var health: int = 1


func to_dict_impl() -> Dictionary:
	var data := super.to_dict_impl()
	data["state_type"] = "harvestable"
	data["health"] = health
	return data


func from_dict_impl(data: Dictionary) -> bool:
	if not SerializationUtil.has_valid_int(data, "health") or int(data.get("health", 1)) < 0:
		return false
	if not super.from_dict_impl(data):
		return false
	health = int(data.get("health", 1))
	return true
