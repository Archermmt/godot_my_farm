class_name ItemState
extends RefCounted

var instance_id: StringName = &""
var meta_id: StringName = &""
var cell: Vector2i = Vector2i.ZERO
var random_seed: int = 0
var flags: Array[StringName] = []


func to_dict_impl() -> Dictionary:
	return {
		"state_type": "item",
		"instance_id": String(instance_id),
		"meta_id": String(meta_id),
		"cell": SerializationUtil.vector2i_to_dict(cell),
		"random_seed": random_seed,
		"flags": SerializationUtil.string_name_array_to_strings(flags),
	}


func from_dict_impl(data: Dictionary) -> bool:
	for key: String in ["instance_id", "meta_id"]:
		if not SerializationUtil.has_valid_string(data, key):
			return false
	if not SerializationUtil.has_valid_int(data, "random_seed"):
		return false
	if not SerializationUtil.has_valid_vector2i(data, "cell") or not SerializationUtil.has_valid_array(data, "flags"):
		return false
	if not SerializationUtil.is_string_array(data.get("flags", []) as Array):
		return false
	if StringName(str(data.get("instance_id", ""))) == &"" or StringName(str(data.get("meta_id", ""))) == &"":
		return false
	instance_id = StringName(str(data.get("instance_id", "")))
	meta_id = StringName(str(data.get("meta_id", "")))
	cell = SerializationUtil.vector2i_from_dict(data.get("cell", {}) as Dictionary)
	random_seed = int(data.get("random_seed", 0))
	flags = SerializationUtil.string_array_to_string_names(data.get("flags", []) as Array)
	return true
