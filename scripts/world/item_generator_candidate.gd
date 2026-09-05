class_name ItemGeneratorCandidate
extends Resource

@export_category("Item")
@export var item_ids: Array[StringName] = []
@export var required_flags: Array[CellState.CellFlag] = [CellState.CellFlag.GENERATE]

@export_category("Amount")
@export_range(0, 999, 1) var min_count: int = 0
@export_range(0, 999, 1) var max_count: int = 0
@export_range(0.0, 1.0, 0.01) var density: float = 0.0

@export_category("Placement")
@export_range(0.0, 32.0, 0.5) var min_distance: float = 0.0
