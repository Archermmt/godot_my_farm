class_name CellState
extends RefCounted

enum CellFlag {
	BASE = 1,
	DIGGABLE = 2,
	DROPABLE = 4,
	ROAD = 8,
	BLOCKED = 16,
	RESOURCE = 32,
	INTERIOR = 64,
}

var cell: Vector2i = Vector2i.ZERO
var flags: int = 0
var dug: bool = false
var watered_on_day: int = 0
var entity_ids: Array[StringName] = []


func to_dict() -> Dictionary:
	return {
		"cell": SerializationUtil.vector2i_to_dict(cell),
		"flags": flags,
		"dug": dug,
		"watered_on_day": watered_on_day,
		"entity_ids": SerializationUtil.string_name_array_to_strings(entity_ids),
	}


static func from_dict(data: Dictionary) -> CellState:
	if not SerializationUtil.has_valid_vector2i(data, "cell"):
		return null
	if not SerializationUtil.has_valid_bool(data, "dug"):
		return null
	if not SerializationUtil.has_valid_int(data, "flags") or not SerializationUtil.has_valid_int(data, "watered_on_day"):
		return null
	if not SerializationUtil.has_valid_array(data, "entity_ids") or not SerializationUtil.is_string_array(data.get("entity_ids", []) as Array):
		return null
	if int(data.get("flags", 0)) < 0 or int(data.get("watered_on_day", 0)) < 0:
		return null
	var restored := CellState.new()
	restored.cell = SerializationUtil.vector2i_from_dict(data.get("cell", {}) as Dictionary)
	restored.flags = int(data.get("flags", 0))
	restored.dug = bool(data.get("dug", false))
	restored.watered_on_day = int(data.get("watered_on_day", 0))
	restored.entity_ids = SerializationUtil.string_array_to_string_names(data.get("entity_ids", []) as Array)
	var unique_ids: Dictionary[StringName, bool] = {}
	for entity_id: StringName in restored.entity_ids:
		if entity_id == &"" or unique_ids.has(entity_id):
			return null
		unique_ids[entity_id] = true
	return restored
