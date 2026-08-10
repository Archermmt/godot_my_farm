class_name ItemStack
extends RefCounted

var item_id: StringName = &""
var amount: int = 0


func _init(p_item_id: StringName = &"", p_amount: int = 0) -> void:
	item_id = p_item_id
	amount = max(0, p_amount)
	if amount == 0:
		item_id = &""


func is_empty() -> bool:
	return item_id == &"" or amount <= 0


func clear() -> void:
	item_id = &""
	amount = 0


func duplicate_stack() -> ItemStack:
	return ItemStack.new(item_id, amount)


func can_merge(other: ItemStack) -> bool:
	return other != null and not is_empty() and not other.is_empty() and item_id == other.item_id


func to_dict() -> Dictionary:
	return {
		"item_id": String(item_id),
		"amount": amount,
	}


static func from_dict(data: Dictionary) -> ItemStack:
	if not SerializationUtil.has_valid_string(data, "item_id"):
		return null
	if not SerializationUtil.has_valid_int(data, "amount"):
		return null
	var raw_amount: int = int(data.get("amount", 0))
	var raw_id := StringName(str(data.get("item_id", "")))
	if raw_amount < 0 or (raw_amount > 0 and raw_id == &""):
		return null
	var restored := ItemStack.new(raw_id, raw_amount)
	return restored
