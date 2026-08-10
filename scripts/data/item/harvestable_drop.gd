class_name HarvestableDrop
extends Resource

@export var item_id: StringName = &""
@export_range(0, 999, 1) var min_amount: int = 1
@export_range(0, 999, 1) var max_amount: int = 1
@export_range(0.0, 1.0, 0.01) var chance: float = 1.0
