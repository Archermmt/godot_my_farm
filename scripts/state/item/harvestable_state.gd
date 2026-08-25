class_name HarvestableState
extends ItemState

func to_dict_impl() -> Dictionary:
	var data := super.to_dict_impl()
	data["state_type"] = "harvestable"
	return data


func from_dict_impl(data: Dictionary) -> bool:
	if not super.from_dict_impl(data):
		return false
	health = int(data.get("health", 1))
	return true
