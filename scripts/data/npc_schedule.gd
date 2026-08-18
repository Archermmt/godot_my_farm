class_name NpcSchedule
extends Resource

@export var id: StringName = &""
@export var npc_id: StringName = &""
@export var display_name: String = "Villager"
@export var body_color: Color = Color("7ab6d8")
@export var accent_color: Color = Color("f2c14e")
@export_range(8.0, 160.0, 1.0) var move_speed: float = 42.0
@export var fallback_map_id: StringName = &"farm"
@export var fallback_cell: Vector2i = Vector2i.ZERO
@export var fallback_behavior_id: StringName = &"idle"
@export var events: Array[NpcScheduleEvent] = []
