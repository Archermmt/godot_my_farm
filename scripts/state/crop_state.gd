class_name CropState
extends RefCounted

var crop_id: StringName = &""
var seed_item_id: StringName = &""
var growth_days: int = 0
var health: int = 1
var planted_on_day: int = 1
var random_seed: int = 0


func to_dict() -> Dictionary:
	return {
		"crop_id": String(crop_id),
		"seed_item_id": String(seed_item_id),
		"growth_days": growth_days,
		"health": health,
		"planted_on_day": planted_on_day,
		"random_seed": random_seed,
	}


static func from_dict(data: Dictionary) -> CropState:
	for key: String in ["crop_id", "seed_item_id"]:
		if not SerializationUtil.has_valid_string(data, key):
			return null
	for key: String in ["growth_days", "health", "planted_on_day", "random_seed"]:
		if not SerializationUtil.has_valid_int(data, key):
			return null
	if StringName(str(data.get("crop_id", ""))) == &"" or StringName(str(data.get("seed_item_id", ""))) == &"":
		return null
	if int(data.get("growth_days", 0)) < 0 or int(data.get("health", 1)) < 0 or int(data.get("planted_on_day", 1)) < 1:
		return null
	var restored := CropState.new()
	restored.crop_id = StringName(str(data.get("crop_id", "")))
	restored.seed_item_id = StringName(str(data.get("seed_item_id", "")))
	restored.growth_days = int(data.get("growth_days", 0))
	restored.health = int(data.get("health", 1))
	restored.planted_on_day = int(data.get("planted_on_day", 1))
	restored.random_seed = int(data.get("random_seed", 0))
	return restored
