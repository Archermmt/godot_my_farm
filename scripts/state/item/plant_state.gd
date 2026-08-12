class_name PlantState
extends HarvestableState

var growth_days: int = 0
var planted_on_day: int = 1
var last_growth_day: int = 0


func state_type() -> StateType:
	return StateType.PLANT


func state_type_name() -> String:
	return "plant"


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["growth_days"] = growth_days
	data["planted_on_day"] = planted_on_day
	data["last_growth_day"] = last_growth_day
	return data


static func from_dict(data: Dictionary) -> PlantState:
	if String(data.get("state_type", "")) != "plant":
		return null
	for key: String in ["health", "growth_days", "planted_on_day", "last_growth_day"]:
		if not SerializationUtil.has_valid_int(data, key):
			return null
	var restored := PlantState.new()
	if not ItemState._read_common(data, restored):
		return null
	if int(data.get("health", 1)) < 0 or int(data.get("growth_days", 0)) < 0 or int(data.get("planted_on_day", 1)) < 1 or int(data.get("last_growth_day", 0)) < 0:
		return null
	restored.health = int(data.get("health", 1))
	restored.growth_days = int(data.get("growth_days", 0))
	restored.planted_on_day = int(data.get("planted_on_day", 1))
	restored.last_growth_day = int(data.get("last_growth_day", 0))
	return restored
