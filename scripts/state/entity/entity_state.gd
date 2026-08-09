class_name EntityState
extends RefCounted

var instance_id: StringName = &""
var definition_id: StringName = &""
var entity_kind: StringName = &"harvestable"
var cell: Vector2i = Vector2i.ZERO
var health: int = 1
var random_seed: int = 0
var flags: Array[StringName] = []


func to_dict() -> Dictionary:
	return {
		"instance_id": String(instance_id),
		"definition_id": String(definition_id),
		"entity_kind": String(entity_kind),
		"cell": SerializationUtil.vector2i_to_dict(cell),
		"health": health,
		"random_seed": random_seed,
		"flags": SerializationUtil.string_name_array_to_strings(flags),
	}


static func has_valid_common_data(data: Dictionary) -> bool:
	for key: String in ["instance_id", "definition_id", "entity_kind"]:
		if not SerializationUtil.has_valid_string(data, key):
			return false
	for key: String in ["health", "random_seed"]:
		if not SerializationUtil.has_valid_int(data, key):
			return false
	if not SerializationUtil.has_valid_vector2i(data, "cell") or not SerializationUtil.has_valid_array(data, "flags"):
		return false
	var raw_flags: Array = data.get("flags", []) as Array
	if not SerializationUtil.is_string_array(raw_flags):
		return false
	if StringName(str(data.get("instance_id", ""))) == &"" or StringName(str(data.get("definition_id", ""))) == &"" or StringName(str(data.get("entity_kind", ""))) == &"":
		return false
	if int(data.get("health", 1)) < 0:
		return false
	return true


func load_common_data(data: Dictionary) -> Error:
	if not has_valid_common_data(data):
		return ERR_INVALID_DATA
	instance_id = StringName(str(data.get("instance_id", "")))
	definition_id = StringName(str(data.get("definition_id", "")))
	entity_kind = StringName(str(data.get("entity_kind", "")))
	cell = SerializationUtil.vector2i_from_dict(data.get("cell", {}) as Dictionary)
	health = int(data.get("health", 1))
	random_seed = int(data.get("random_seed", 0))
	flags = SerializationUtil.string_array_to_string_names(data.get("flags", []) as Array)
	return OK


static func from_dict(data: Dictionary) -> EntityState:
	if not has_valid_common_data(data):
		return null
	if StringName(str(data.get("entity_kind", ""))) == &"crop":
		return CropEntityState.from_dict(data)
	var restored := EntityState.new()
	if restored.load_common_data(data) != OK:
		return null
	return restored
