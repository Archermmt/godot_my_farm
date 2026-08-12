class_name PlantStageMeta
extends Resource

@export_range(0, 999, 1) var start_day: int = 0
@export_range(1, 999, 1) var max_health: int = 1
@export var texture: Texture2D = null
@export var visual_offset: Vector2 = Vector2(0, -5)
@export var state_tags: Array[StringName] = []
@export var drop_table_id: StringName = &""
