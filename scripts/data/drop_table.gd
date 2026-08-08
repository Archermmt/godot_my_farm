class_name DropTable
extends Resource

@export var id: StringName = &""
@export var entries: Array[DropTableEntry] = []


func duplicate_table() -> DropTable:
	var table := DropTable.new()
	table.id = id
	for entry: DropTableEntry in entries:
		table.entries.append(entry.duplicate_entry() if entry != null else null)
	return table
