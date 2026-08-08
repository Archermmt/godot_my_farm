class_name WorldEntityState
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


static func from_dict(data: Dictionary) -> WorldEntityState:
	for key: String in ["instance_id", "definition_id", "entity_kind"]:
		if not SerializationUtil.has_valid_string(data, key):
			return null
	for key: String in ["health", "random_seed"]:
		if not SerializationUtil.has_valid_int(data, key):
			return null
	if not SerializationUtil.has_valid_vector2i(data, "cell") or not SerializationUtil.has_valid_array(data, "flags"):
		return null
	var raw_flags: Array = data.get("flags", []) as Array
	if not SerializationUtil.is_string_array(raw_flags):
		return null
	if StringName(str(data.get("instance_id", ""))) == &"" or StringName(str(data.get("definition_id", ""))) == &"":
		return null
	if int(data.get("health", 1)) < 0:
		return null
	var restored := WorldEntityState.new()
	restored.instance_id = StringName(str(data.get("instance_id", "")))
	restored.definition_id = StringName(str(data.get("definition_id", "")))
	restored.entity_kind = StringName(str(data.get("entity_kind", "harvestable")))
	restored.cell = SerializationUtil.vector2i_from_dict(data.get("cell", {}) as Dictionary)
	restored.health = int(data.get("health", 1))
	restored.random_seed = int(data.get("random_seed", 0))
	restored.flags = SerializationUtil.string_array_to_string_names(raw_flags)
	return restored
