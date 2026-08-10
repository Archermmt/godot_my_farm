class_name ItemState
extends RefCounted

enum StateType { ITEM, PLANT, HARVESTABLE }

var instance_id: StringName = &""
var meta_id: StringName = &""
var cell: Vector2i = Vector2i.ZERO
var random_seed: int = 0
var flags: Array[StringName] = []


func state_type() -> StateType:
	return StateType.ITEM


func state_type_name() -> String:
	return "item"


func to_dict() -> Dictionary:
	return {
		"state_type": state_type_name(),
		"instance_id": String(instance_id),
		"meta_id": String(meta_id),
		"cell": SerializationUtil.vector2i_to_dict(cell),
		"random_seed": random_seed,
		"flags": SerializationUtil.string_name_array_to_strings(flags),
	}


static func from_dict(data: Dictionary) -> ItemState:
	if not SerializationUtil.has_valid_string(data, "state_type"):
		return null
	match String(data.get("state_type", "")):
		"item":
			return _from_dict_as_item(data)
		"plant":
			return PlantState.from_dict(data)
		"harvestable":
			return HarvestableState.from_dict(data)
		_:
			return null


static func _from_dict_as_item(data: Dictionary) -> ItemState:
	var restored := ItemState.new()
	if not _read_common(data, restored):
		return null
	return restored


static func _read_common(data: Dictionary, restored: ItemState) -> bool:
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
	restored.instance_id = StringName(str(data.get("instance_id", "")))
	restored.meta_id = StringName(str(data.get("meta_id", "")))
	restored.cell = SerializationUtil.vector2i_from_dict(data.get("cell", {}) as Dictionary)
	restored.random_seed = int(data.get("random_seed", 0))
	restored.flags = SerializationUtil.string_array_to_string_names(data.get("flags", []) as Array)
	return true
