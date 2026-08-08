class_name FarmCellState
extends RefCounted

var cell: Vector2i = Vector2i.ZERO
var dug: bool = false
var watered_on_day: int = 0
var occupant_id: StringName = &""
var crop: CropState = null


func is_watered(current_day: int) -> bool:
	return watered_on_day == current_day


func to_dict() -> Dictionary:
	return {
		"cell": SerializationUtil.vector2i_to_dict(cell),
		"dug": dug,
		"watered_on_day": watered_on_day,
		"occupant_id": String(occupant_id),
		"crop": crop.to_dict() if crop != null else {},
	}


static func from_dict(data: Dictionary) -> FarmCellState:
	if not SerializationUtil.has_valid_vector2i(data, "cell"):
		return null
	if not SerializationUtil.has_valid_bool(data, "dug"):
		return null
	if not SerializationUtil.has_valid_int(data, "watered_on_day"):
		return null
	if not SerializationUtil.has_valid_string(data, "occupant_id"):
		return null
	if not SerializationUtil.has_valid_dictionary(data, "crop"):
		return null
	if int(data.get("watered_on_day", 0)) < 0:
		return null
	var restored := FarmCellState.new()
	restored.cell = SerializationUtil.vector2i_from_dict(data.get("cell", {}) as Dictionary)
	restored.dug = bool(data.get("dug", false))
	restored.watered_on_day = max(0, int(data.get("watered_on_day", 0)))
	restored.occupant_id = StringName(str(data.get("occupant_id", "")))
	var crop_data: Dictionary = data.get("crop", {}) as Dictionary
	if not crop_data.is_empty():
		restored.crop = CropState.from_dict(crop_data)
		if restored.crop == null:
			return null
	return restored
