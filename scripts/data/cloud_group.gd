class_name CloudGroup
extends Resource

@export_range(1, 64, 1) var shadow_count: int = 12
@export_range(0.2, 3.0, 0.05) var shadow_scale: float = 0.9
@export_range(0.05, 1.0, 0.01) var shadow_alpha: float = 0.34
@export var shadow_color: Color = Color(0.38, 0.43, 0.48, 1.0)

