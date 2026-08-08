class_name NpcState
extends RefCounted

var npc_id: StringName = &""
var schedule_id: StringName = &""
var map_id: StringName = &"farm"
var cell: Vector2i = Vector2i.ZERO
var facing: StringName = &"down"
var behavior_id: StringName = &"idle"
var current_event_id: StringName = &""


func to_dict() -> Dictionary:
	return {
		"npc_id": String(npc_id),
		"schedule_id": String(schedule_id),
		"map_id": String(map_id),
		"cell": SerializationUtil.vector2i_to_dict(cell),
		"facing": String(facing),
		"behavior_id": String(behavior_id),
		"current_event_id": String(current_event_id),
	}


static func from_dict(data: Dictionary) -> NpcState:
	for key: String in ["npc_id", "schedule_id", "map_id", "facing", "behavior_id", "current_event_id"]:
		if not SerializationUtil.has_valid_string(data, key):
			return null
	if not SerializationUtil.has_valid_vector2i(data, "cell"):
		return null
	if StringName(str(data.get("npc_id", ""))) == &"" or StringName(str(data.get("map_id", "farm"))) == &"":
		return null
	var restored := NpcState.new()
	restored.npc_id = StringName(str(data.get("npc_id", "")))
	restored.schedule_id = StringName(str(data.get("schedule_id", "")))
	restored.map_id = StringName(str(data.get("map_id", "farm")))
	restored.cell = SerializationUtil.vector2i_from_dict(data.get("cell", {}) as Dictionary)
	restored.facing = StringName(str(data.get("facing", "down")))
	restored.behavior_id = StringName(str(data.get("behavior_id", "idle")))
	restored.current_event_id = StringName(str(data.get("current_event_id", "")))
	return restored
