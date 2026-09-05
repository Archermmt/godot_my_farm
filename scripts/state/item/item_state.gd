class_name ItemState
extends RefCounted

var unique_id: StringName = &""
var meta_id: StringName = &""
var position: Vector2 = Vector2.ZERO
var flags: Array[ItemMeta.ItemFlag] = [ItemMeta.ItemFlag.AVAILABLE]
var health: int = 1


func add_flag(flag: ItemMeta.ItemFlag) -> void:
	if not has_flag(flag):
		flags.append(flag)


func remove_flag(flag: ItemMeta.ItemFlag) -> void:
	flags.erase(flag)


func has_flag(flag: ItemMeta.ItemFlag) -> bool:
	return flag in flags


func to_dict_impl() -> Dictionary:
	return {
		"state_type": "item",
		"unique_id": String(unique_id),
		"meta_id": String(meta_id),
		"position": SerializationUtil.vector2_to_dict(position),
		"flags": flags,
		"health": health,
	}


func from_dict_impl(data: Dictionary) -> bool:
	for key: String in ["unique_id", "meta_id"]:
		if not SerializationUtil.has_valid_string(data, key):
			return false
	if data.has("health") and (not SerializationUtil.has_valid_int(data, "health") or int(data.get("health", 1)) < 0):
		return false
	if not SerializationUtil.has_valid_vector2(data, "position") or not SerializationUtil.has_valid_array(data, "flags"):
		return false
	var restored_flags: Array[ItemMeta.ItemFlag] = []
	for value: Variant in data.get("flags", []) as Array:
		if (
			not SerializationUtil.has_valid_int({"value": value}, "value")
			or int(value) < ItemMeta.ItemFlag.AVAILABLE
			or int(value) > ItemMeta.ItemFlag.GENERATED
			or int(value) in restored_flags
		):
			return false
		restored_flags.append(int(value) as ItemMeta.ItemFlag)
	if StringName(str(data.get("unique_id", ""))) == &"" or StringName(str(data.get("meta_id", ""))) == &"":
		return false
	unique_id = StringName(str(data.get("unique_id", "")))
	meta_id = StringName(str(data.get("meta_id", "")))
	position = SerializationUtil.vector2_from_dict(data.get("position", {}) as Dictionary)
	flags = restored_flags
	health = maxi(0, int(data.get("health", 1)))
	return true
