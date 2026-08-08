class_name InventoryState
extends RefCounted

var owner_id: StringName = &"player"
var slots: Array[ItemStack] = []
var selected_index: int = 0


func _init(slot_count: int = 20, p_owner_id: StringName = &"player") -> void:
	owner_id = p_owner_id
	_resize_slots(slot_count)


func capacity() -> int:
	return slots.size()


func get_slot(index: int) -> ItemStack:
	if not _is_valid_index(index):
		return null
	return slots[index]


func set_slot(index: int, stack: ItemStack) -> bool:
	if not _is_valid_index(index):
		return false
	slots[index] = stack.duplicate_stack() if stack != null else ItemStack.new()
	return true


func select_slot(index: int) -> bool:
	if not _is_valid_index(index):
		return false
	selected_index = index
	return true


func selected_stack() -> ItemStack:
	return get_slot(selected_index)


func can_add_item(item_id: StringName, amount: int, stack_limit: int) -> bool:
	if item_id == &"" or amount <= 0 or stack_limit <= 0:
		return false
	return _free_space_for(item_id, stack_limit) >= amount


func add_item(item_id: StringName, amount: int, stack_limit: int) -> bool:
	if not can_add_item(item_id, amount, stack_limit):
		return false
	var remaining: int = amount
	for slot: ItemStack in slots:
		if remaining == 0:
			break
		if not slot.is_empty() and slot.item_id == item_id and slot.amount < stack_limit:
			var moved: int = min(remaining, stack_limit - slot.amount)
			slot.amount += moved
			remaining -= moved
	for slot: ItemStack in slots:
		if remaining == 0:
			break
		if slot.is_empty():
			var moved: int = min(remaining, stack_limit)
			slot.item_id = item_id
			slot.amount = moved
			remaining -= moved
	return true


func can_remove_item(item_id: StringName, amount: int) -> bool:
	if item_id == &"" or amount <= 0:
		return false
	return count_item(item_id) >= amount


func remove_item(item_id: StringName, amount: int) -> bool:
	if not can_remove_item(item_id, amount):
		return false
	var remaining: int = amount
	for slot: ItemStack in slots:
		if remaining == 0:
			break
		if slot.item_id == item_id:
			var removed: int = min(remaining, slot.amount)
			slot.amount -= removed
			remaining -= removed
			if slot.amount == 0:
				slot.clear()
	return true


func swap_slots(index_a: int, index_b: int) -> bool:
	if not _is_valid_index(index_a) or not _is_valid_index(index_b):
		return false
	if index_a == index_b:
		return true
	var temp: ItemStack = slots[index_a]
	slots[index_a] = slots[index_b]
	slots[index_b] = temp
	return true


func merge_slots(source_index: int, target_index: int, stack_limit: int) -> bool:
	if not _is_valid_index(source_index) or not _is_valid_index(target_index) or stack_limit <= 0:
		return false
	if source_index == target_index:
		return true
	var source: ItemStack = slots[source_index]
	var target: ItemStack = slots[target_index]
	if source.is_empty():
		return true
	if target.is_empty():
		slots[target_index] = source.duplicate_stack()
		source.clear()
		return true
	if not target.can_merge(source):
		return false
	if target.amount + source.amount > stack_limit:
		return false
	target.amount += source.amount
	source.clear()
	return true


func exchange_with(other: InventoryState, this_index: int, other_index: int) -> bool:
	if other == null or not _is_valid_index(this_index) or not other._is_valid_index(other_index):
		return false
	var temp: ItemStack = slots[this_index]
	slots[this_index] = other.slots[other_index]
	other.slots[other_index] = temp
	return true


func count_item(item_id: StringName) -> int:
	var total: int = 0
	for slot: ItemStack in slots:
		if slot.item_id == item_id:
			total += slot.amount
	return total


func to_dict() -> Dictionary:
	var slot_data: Array[Dictionary] = []
	for slot: ItemStack in slots:
		slot_data.append(slot.to_dict())
	return {
		"owner_id": String(owner_id),
		"selected_index": selected_index,
		"slots": slot_data,
	}


static func from_dict(data: Dictionary) -> InventoryState:
	if not SerializationUtil.has_valid_string(data, "owner_id"):
		return null
	if not SerializationUtil.has_valid_int(data, "selected_index"):
		return null
	if not SerializationUtil.has_valid_array(data, "slots"):
		return null
	var raw_slots: Array = data.get("slots", []) as Array
	var restored := InventoryState.new(raw_slots.size(), StringName(str(data.get("owner_id", "player"))))
	for index: int in raw_slots.size():
		if typeof(raw_slots[index]) != TYPE_DICTIONARY:
			return null
		var slot_dict: Dictionary = raw_slots[index] as Dictionary
		var restored_stack := ItemStack.from_dict(slot_dict)
		if restored_stack == null:
			return null
		restored.slots[index] = restored_stack
	var raw_selected: int = int(data.get("selected_index", 0))
	if (raw_slots.is_empty() and raw_selected != -1 and raw_selected != 0) or (not raw_slots.is_empty() and (raw_selected < 0 or raw_selected >= raw_slots.size())):
		return null
	restored.selected_index = -1 if raw_slots.is_empty() else raw_selected
	return restored


func _resize_slots(slot_count: int) -> void:
	slots.clear()
	for _index: int in max(0, slot_count):
		slots.append(ItemStack.new())
	if slots.is_empty():
		selected_index = -1
	else:
		selected_index = clampi(selected_index, 0, slots.size() - 1)


func _free_space_for(item_id: StringName, stack_limit: int) -> int:
	var free_space: int = 0
	for slot: ItemStack in slots:
		if slot.is_empty():
			free_space += stack_limit
		elif slot.item_id == item_id and slot.amount < stack_limit:
			free_space += stack_limit - slot.amount
	return free_space


func _is_valid_index(index: int) -> bool:
	return index >= 0 and index < slots.size()
