class_name NpcSchedule
extends Resource

@export var id: StringName = &""
@export var npc_id: StringName = &""
@export var fallback_map_id: StringName = &"farm"
@export var fallback_cell: Vector2i = Vector2i.ZERO
@export var events: Array[NpcScheduleEvent] = []
