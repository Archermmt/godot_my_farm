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
	DUG = 128,
	WATERED = 256,
	GENERATE = 512
}

const PERSISTENT_FLAGS := CellFlag.DUG | CellFlag.WATERED

enum CellCondition { WALKABLE, DIGGABLE, DUG, WATERED, HAS_OCCUPANT, PLANTABLE, DROPABLE }

enum InteractionFlag { NONE = 0, VALID = 1, INVALID = 2, ENTITY = 4 }

var cell: Vector2i = Vector2i.ZERO
var flags: int = 0
var item_ids: Array[StringName] = []
var interaction_flags: int = InteractionFlag.NONE


func to_dict() -> Dictionary:
	return {
		"cell": SerializationUtil.vector2i_to_dict(cell),
		"flags": flags & PERSISTENT_FLAGS,
		"item_ids": SerializationUtil.string_name_array_to_strings(item_ids),
	}


static func from_dict(data: Dictionary) -> CellState:
	if not SerializationUtil.has_valid_vector2i(data, "cell"):
		return null
	if not SerializationUtil.has_valid_int(data, "flags"):
		return null
	if (
		not SerializationUtil.has_valid_array(data, "item_ids")
		or not SerializationUtil.is_string_array(data.get("item_ids", []) as Array)
	):
		return null
	if int(data.get("flags", 0)) < 0:
		return null
	var restored := CellState.new()
	restored.cell = SerializationUtil.vector2i_from_dict(data.get("cell", {}) as Dictionary)
	restored.flags = int(data.get("flags", 0)) & PERSISTENT_FLAGS
	restored.item_ids = SerializationUtil.string_array_to_string_names(data.get("item_ids", []) as Array)
	var unique_ids: Dictionary[StringName, bool] = {}
	for item_id: StringName in restored.item_ids:
		if item_id == &"" or unique_ids.has(item_id):
			return null
		unique_ids[item_id] = true
	return restored
