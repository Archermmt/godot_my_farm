class_name BackpackSlot
extends Resource

@export var slot_id: StringName = &""
@export var item_id: StringName = &""
@export_range(0, 999, 1) var amount: int = 0


func _init(p_slot_id: StringName = &"", p_item_id: StringName = &"", p_amount: int = 0) -> void:
	slot_id = p_slot_id
	item_id = p_item_id
	amount = max(0, p_amount)
	if amount == 0:
		item_id = &""


func is_empty() -> bool:
	return item_id == &"" or amount <= 0


func clear() -> void:
	item_id = &""
	amount = 0


func duplicate_slot() -> BackpackSlot:
	return BackpackSlot.new(slot_id, item_id, amount)


func can_merge(other: BackpackSlot) -> bool:
	return other != null and not is_empty() and not other.is_empty() and item_id == other.item_id


func to_dict() -> Dictionary:
	return {
		"slot_id": String(slot_id),
		"item_id": String(item_id),
		"amount": amount,
	}


static func from_dict(data: Dictionary) -> BackpackSlot:
	if not SerializationUtil.has_valid_string(data, "slot_id"):
		return null
	if not SerializationUtil.has_valid_string(data, "item_id"):
		return null
	if not SerializationUtil.has_valid_int(data, "amount"):
		return null
	var raw_amount := int(data.get("amount", 0))
	var raw_item_id := StringName(str(data.get("item_id", "")))
	if raw_amount < 0 or (raw_amount > 0 and raw_item_id == &""):
		return null
	return BackpackSlot.new(
		StringName(str(data.get("slot_id", ""))),
		raw_item_id,
		raw_amount
	)
