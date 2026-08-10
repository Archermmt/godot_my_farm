class_name HarvestableState
extends ItemState

var health: int = 1


func state_type() -> StateType:
	return StateType.HARVESTABLE


func state_type_name() -> String:
	return "harvestable"


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["health"] = health
	return data


static func from_dict(data: Dictionary) -> HarvestableState:
	if String(data.get("state_type", "")) != "harvestable":
		return null
	if not SerializationUtil.has_valid_int(data, "health"):
		return null
	var restored := HarvestableState.new()
	if not ItemState._read_common(data, restored):
		return null
	if int(data.get("health", 1)) < 0:
		return null
	restored.health = int(data.get("health", 1))
	return restored
