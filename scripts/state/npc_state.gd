class_name NpcState
extends RefCounted

var npc_id: StringName = &""
var schedule_id: StringName = &""
var map_id: StringName = &"farm"
var current_position: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var behavior_id: StringName = &"idle"
var current_event_id: StringName = &""


static func from_schedule(schedule: NpcSchedule, owner_id: StringName = &"") -> NpcState:
	if schedule == null or owner_id == &"":
		return null
	var state := NpcState.new()
	state.npc_id = owner_id
	state.schedule_id = schedule.id
	state.map_id = schedule.map_id
	state.current_position = schedule.target_position
	state.target_position = schedule.target_position
	state.behavior_id = schedule.behavior_id
	return state


func to_dict() -> Dictionary:
	return {
		"npc_id": String(npc_id),
		"schedule_id": String(schedule_id),
		"map_id": String(map_id),
		"current_position": SerializationUtil.vector2_to_dict(current_position),
		"target_position": SerializationUtil.vector2_to_dict(target_position),
		"behavior_id": String(behavior_id),
		"current_event_id": String(current_event_id),
	}


static func from_dict(data: Dictionary) -> NpcState:
	for key: String in ["npc_id", "schedule_id", "map_id", "behavior_id", "current_event_id"]:
		if not SerializationUtil.has_valid_string(data, key):
			return null
	if not SerializationUtil.has_valid_vector2(data, "current_position") or not SerializationUtil.has_valid_vector2(data, "target_position"):
		return null
	if StringName(str(data.get("npc_id", ""))) == &"" or StringName(str(data.get("map_id", "farm"))) == &"":
		return null
	var restored := NpcState.new()
	restored.npc_id = StringName(str(data.get("npc_id", "")))
	restored.schedule_id = StringName(str(data.get("schedule_id", "")))
	restored.map_id = StringName(str(data.get("map_id", "farm")))
	restored.current_position = SerializationUtil.vector2_from_dict(data.get("current_position", {}) as Dictionary)
	restored.target_position = SerializationUtil.vector2_from_dict(data.get("target_position", {}) as Dictionary)
	restored.behavior_id = StringName(str(data.get("behavior_id", "idle")))
	restored.current_event_id = StringName(str(data.get("current_event_id", "")))
	return restored
