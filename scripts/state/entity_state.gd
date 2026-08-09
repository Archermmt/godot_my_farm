class_name EntityState
extends RefCounted

enum EntityType {
	NONE,
	GENERIC,
	CROP,
	HARVESTABLE,
	PICKUP,
	NPC,
}

var instance_id: StringName = &""
var definition_id: StringName = &""
var type: EntityType = EntityType.GENERIC
var cell: Vector2i = Vector2i.ZERO
var health: int = 1
var random_seed: int = 0
var flags: Array[StringName] = []
var seed_item_id: StringName = &""
var growth_days: int = 0
var planted_on_day: int = 1


func to_dict() -> Dictionary:
	return {
		"instance_id": String(instance_id),
		"definition_id": String(definition_id),
		"type": int(type),
		"cell": SerializationUtil.vector2i_to_dict(cell),
		"health": health,
		"random_seed": random_seed,
		"flags": SerializationUtil.string_name_array_to_strings(flags),
		"seed_item_id": String(seed_item_id),
		"growth_days": growth_days,
		"planted_on_day": planted_on_day,
	}


static func from_dict(data: Dictionary) -> EntityState:
	for key: String in ["instance_id", "definition_id", "seed_item_id"]:
		if not SerializationUtil.has_valid_string(data, key):
			return null
	for key: String in ["type", "health", "random_seed", "growth_days", "planted_on_day"]:
		if not SerializationUtil.has_valid_int(data, key):
			return null
	if not SerializationUtil.has_valid_vector2i(data, "cell") or not SerializationUtil.has_valid_array(data, "flags"):
		return null
	if not SerializationUtil.is_string_array(data.get("flags", []) as Array):
		return null
	var restored_type := int(data.get("type", EntityType.NONE)) as EntityType
	if restored_type <= EntityType.NONE or restored_type > EntityType.NPC:
		return null
	if StringName(str(data.get("instance_id", ""))) == &"" or StringName(str(data.get("definition_id", ""))) == &"":
		return null
	if int(data.get("health", 1)) < 0 or int(data.get("growth_days", 0)) < 0 or int(data.get("planted_on_day", 1)) < 1:
		return null
	var restored := EntityState.new()
	restored.instance_id = StringName(str(data.get("instance_id", "")))
	restored.definition_id = StringName(str(data.get("definition_id", "")))
	restored.type = restored_type
	restored.cell = SerializationUtil.vector2i_from_dict(data.get("cell", {}) as Dictionary)
	restored.health = int(data.get("health", 1))
	restored.random_seed = int(data.get("random_seed", 0))
	restored.flags = SerializationUtil.string_array_to_string_names(data.get("flags", []) as Array)
	restored.seed_item_id = StringName(str(data.get("seed_item_id", "")))
	restored.growth_days = int(data.get("growth_days", 0))
	restored.planted_on_day = int(data.get("planted_on_day", 1))
	return restored
