class_name NpcScheduleEvent
extends Resource

@export var id: StringName = &""
@export var seasons: Array[StringName] = []
@export var weekdays: Array[int] = []
@export_range(0, 1439, 1) var start_minute: int = 360
@export_range(1, 1440, 1) var duration_minutes: int = 60
@export var map_id: StringName = &"farm"
@export var target_spawn_id: StringName = &""
@export var target_cell: Vector2i = Vector2i.ZERO
@export var behavior_id: StringName = &"idle"
