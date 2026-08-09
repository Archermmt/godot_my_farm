class_name CropEntityState
extends EntityState

var seed_item_id: StringName = &""
var growth_days: int = 0
var planted_on_day: int = 1


func _init() -> void:
	entity_kind = &"crop"


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["seed_item_id"] = String(seed_item_id)
	data["growth_days"] = growth_days
	data["planted_on_day"] = planted_on_day
	return data


static func from_dict(data: Dictionary) -> CropEntityState:
	if not EntityState.has_valid_common_data(data) or StringName(str(data.get("entity_kind", ""))) != &"crop":
		return null
	if not SerializationUtil.has_valid_string(data, "seed_item_id"):
		return null
	for key: String in ["growth_days", "planted_on_day"]:
		if not SerializationUtil.has_valid_int(data, key):
			return null
	if StringName(str(data.get("seed_item_id", ""))) == &"":
		return null
	if int(data.get("growth_days", 0)) < 0 or int(data.get("planted_on_day", 1)) < 1:
		return null
	var restored := CropEntityState.new()
	if restored.load_common_data(data) != OK:
		return null
	restored.seed_item_id = StringName(str(data.get("seed_item_id", "")))
	restored.growth_days = int(data.get("growth_days", 0))
	restored.planted_on_day = int(data.get("planted_on_day", 1))
	return restored
