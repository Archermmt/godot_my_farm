class_name ItembarState
extends InventoryState

const DEFAULT_CAPACITY := 10


func _init(slot_count: int = DEFAULT_CAPACITY) -> void:
	super(slot_count, &"itembar")


func accepts(meta: ItemMeta) -> bool:
	return meta != null and not meta.is_tool() and meta.use_kind != ItemMeta.UseKind.NONE


static func from_dict(data: Dictionary) -> ItembarState:
	var restored_base := InventoryState.from_dict(data)
	if restored_base == null or restored_base.owner_id != &"itembar":
		return null
	var restored := ItembarState.new(restored_base.capacity())
	restored.slots = restored_base.slots
	restored.selected_index = restored_base.selected_index
	return restored
