class_name DropTableEntry
extends Resource

@export var item_id: StringName = &""
@export_range(0, 999, 1) var min_amount: int = 1
@export_range(0, 999, 1) var max_amount: int = 1
@export_range(0.0, 1.0, 0.01) var chance: float = 1.0
@export_range(0, 999, 1) var weight: int = 1


func duplicate_entry() -> DropTableEntry:
	var entry := DropTableEntry.new()
	entry.item_id = item_id
	entry.min_amount = min_amount
	entry.max_amount = max_amount
	entry.chance = chance
	entry.weight = weight
	return entry
