class_name PlantState
extends HarvestableState

var growth_days: int = 0
var planted_on_day: int = 1
var last_growth_day: int = 0


func to_dict_impl() -> Dictionary:
	var data := super.to_dict_impl()
	data["state_type"] = "plant"
	data["growth_days"] = growth_days
	data["planted_on_day"] = planted_on_day
	data["last_growth_day"] = last_growth_day
	return data


func from_dict_impl(data: Dictionary) -> bool:
	for key: String in ["growth_days", "planted_on_day", "last_growth_day"]:
		if not SerializationUtil.has_valid_int(data, key):
			return false
	if int(data.get("growth_days", 0)) < 0 or int(data.get("planted_on_day", 1)) < 1 or int(data.get("last_growth_day", 0)) < 0:
		return false
	if not super.from_dict_impl(data):
		return false
	growth_days = int(data.get("growth_days", 0))
	planted_on_day = int(data.get("planted_on_day", 1))
	last_growth_day = int(data.get("last_growth_day", 0))
	return true
