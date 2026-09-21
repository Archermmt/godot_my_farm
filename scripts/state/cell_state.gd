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

var coord: Vector2i = Vector2i.ZERO
var item_ids: Array[StringName] = []
var flags: int = 0
var interaction_flags: int = InteractionFlag.NONE
# Transient targeting state; these flags are not persisted with map state.
var usable: bool = false
var invalid: bool = false


func to_dict() -> Dictionary:
	return {
		"coord": SerializationUtil.vector2i_to_dict(coord),
		"item_ids": item_ids.map(func(item_id: StringName) -> String: return String(item_id)),
		"flags": flags & PERSISTENT_FLAGS,
	}


static func from_dict(data: Dictionary) -> CellState:
	if not SerializationUtil.has_valid_vector2i(data, "coord"):
		return null
	if data.has("item_ids") and not SerializationUtil.has_valid_array(data, "item_ids"):
		return null
	if not SerializationUtil.has_valid_int(data, "flags"):
		return null
	if int(data.get("flags", 0)) < 0:
		return null
	var restored := CellState.new()
	restored.coord = SerializationUtil.vector2i_from_dict(data.get("coord", {}) as Dictionary)
	for raw_item_id: Variant in data.get("item_ids", []) as Array:
		if typeof(raw_item_id) != TYPE_STRING or StringName(str(raw_item_id)) == &"":
			return null
		restored.item_ids.append(StringName(str(raw_item_id)))
	restored.flags = int(data.get("flags", 0)) & PERSISTENT_FLAGS
	return restored
