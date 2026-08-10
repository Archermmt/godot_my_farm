class_name ToolbarState
extends InventoryState

const DEFAULT_CAPACITY := 6


func _init(slot_count: int = DEFAULT_CAPACITY) -> void:
	super(slot_count, &"toolbar")


func accepts(meta: ItemMeta) -> bool:
	return meta != null and meta.is_tool()


static func from_dict(data: Dictionary) -> ToolbarState:
	var restored_base := InventoryState.from_dict(data)
	if restored_base == null or restored_base.owner_id != &"toolbar":
		return null
	var restored := ToolbarState.new(restored_base.capacity())
	restored.slots = restored_base.slots
	restored.selected_index = restored_base.selected_index
	return restored
