class_name PlantState
extends HarvestableState

var last_growth_day: int = 0


func to_dict_impl() -> Dictionary:
	var data := super.to_dict_impl()
	data["state_type"] = "plant"
	data["last_growth_day"] = last_growth_day
	return data


func from_dict_impl(data: Dictionary) -> bool:
	for key: String in ["last_growth_day"]:
		if not SerializationUtil.has_valid_int(data, key):
			return false
	if int(data.get("last_growth_day", 0)) < 0:
		return false
	if not super.from_dict_impl(data):
		return false
	last_growth_day = int(data.get("last_growth_day", 0))
	return true
