class_name BackpackState
extends Resource

const DEFAULT_INVENTORY_CAPACITY := 20
const DEFAULT_TOOLBAR_CAPACITY := 6
const DEFAULT_ITEMBAR_CAPACITY := 10

@export var slots: Dictionary[StringName, BackpackSlot] = {}
@export var toolbar: Array[StringName] = []
@export var itembar: Array[StringName] = []
@export var inventory_capacity: int = DEFAULT_INVENTORY_CAPACITY
@export var selected_toolbar_index: int = 0
@export var selected_itembar_index: int = 0


func _init(
	p_inventory_capacity: int = DEFAULT_INVENTORY_CAPACITY,
	p_toolbar_capacity: int = DEFAULT_TOOLBAR_CAPACITY,
	p_itembar_capacity: int = DEFAULT_ITEMBAR_CAPACITY
) -> void:
	inventory_capacity = maxi(0, p_inventory_capacity)
	_ensure_layout(p_toolbar_capacity, p_itembar_capacity)


func inventory_slot_id(index: int) -> StringName:
	return StringName("inventory_%d" % index)


func ensure_layout() -> void:
	_ensure_layout(toolbar.size(), itembar.size())


func toolbar_slot_id(index: int) -> StringName:
	return toolbar[index] if index >= 0 and index < toolbar.size() else &""


func itembar_slot_id(index: int) -> StringName:
	return itembar[index] if index >= 0 and index < itembar.size() else &""


func capacity(container_id: StringName) -> int:
	match container_id:
		&"inventory":
			return inventory_capacity
		&"toolbar":
			return toolbar.size()
		&"itembar":
			return itembar.size()
	return 0


func get_slot(container_id: StringName, index: int) -> BackpackSlot:
	var slot_id := _slot_id(container_id, index)
	return slots.get(slot_id, null) as BackpackSlot


func set_slot(container_id: StringName, index: int, value: BackpackSlot) -> bool:
	var slot_id := _slot_id(container_id, index)
	if slot_id == &"":
		return false
	var replacement := value.duplicate_slot() if value != null else BackpackSlot.new(slot_id)
	replacement.slot_id = slot_id
	slots[slot_id] = replacement
	return true


func selected_slot(source: PlayerState.ActiveHandSource) -> BackpackSlot:
	match source:
		PlayerState.ActiveHandSource.TOOLBAR:
			return get_slot(&"toolbar", selected_toolbar_index)
		PlayerState.ActiveHandSource.ITEMBAR:
			return get_slot(&"itembar", selected_itembar_index)
	return null


func select_bar_index(source: PlayerState.ActiveHandSource, index: int) -> bool:
	if source == PlayerState.ActiveHandSource.TOOLBAR:
		if index < 0 or index >= toolbar.size():
			return false
		selected_toolbar_index = index
		return true
	if source == PlayerState.ActiveHandSource.ITEMBAR:
		if index < 0 or index >= itembar.size():
			return false
		selected_itembar_index = index
		return true
	return false


func accepts(container_id: StringName, meta: ItemMeta) -> bool:
	if meta == null:
		return false
	if container_id == &"toolbar":
		return meta.is_tool()
	if container_id == &"itembar":
		return not meta.is_tool() and not meta is HarvestableMeta
	return container_id == &"inventory"


func add_item(container_id: StringName, item_id: StringName, amount: int, stack_limit: int) -> bool:
	return add_item_partial(container_id, item_id, amount, stack_limit) == amount


func add_item_partial(container_id: StringName, item_id: StringName, amount: int, stack_limit: int) -> int:
	if item_id == &"" or amount <= 0 or stack_limit <= 0:
		return 0
	var available := _free_space_for(container_id, item_id, stack_limit)
	var accepted := mini(amount, available)
	var remaining := accepted
	for index: int in capacity(container_id):
		var slot := get_slot(container_id, index)
		if slot != null and not slot.is_empty() and slot.item_id == item_id and slot.amount < stack_limit:
			var moved := mini(remaining, stack_limit - slot.amount)
			slot.amount += moved
			remaining -= moved
			if remaining == 0:
				return accepted
	for index: int in capacity(container_id):
		var empty_slot := get_slot(container_id, index)
		if empty_slot != null and empty_slot.is_empty():
			var moved := mini(remaining, stack_limit)
			empty_slot.item_id = item_id
			empty_slot.amount = moved
			remaining -= moved
			if remaining == 0:
				break
	return accepted


func remove_item(container_id: StringName, item_id: StringName, amount: int) -> bool:
	if item_id == &"" or amount <= 0 or count_item(container_id, item_id) < amount:
		return false
	var remaining := amount
	for index: int in capacity(container_id):
		var slot := get_slot(container_id, index)
		if slot == null or slot.item_id != item_id:
			continue
		var removed := mini(remaining, slot.amount)
		slot.amount -= removed
		remaining -= removed
		if slot.amount == 0:
			slot.clear()
		if remaining == 0:
			return true
	return false


func count_item(container_id: StringName, item_id: StringName) -> int:
	var total := 0
	for index: int in capacity(container_id):
		var slot := get_slot(container_id, index)
		if slot != null and slot.item_id == item_id:
			total += slot.amount
	return total


func switch_item(source_container: StringName, source_index: int, target_container: StringName, target_index: int) -> bool:
	var source := get_slot(source_container, source_index)
	var target := get_slot(target_container, target_index)
	if source == null or target == null:
		return false
	var source_copy := source.duplicate_slot()
	var target_copy := target.duplicate_slot()
	set_slot(source_container, source_index, target_copy)
	set_slot(target_container, target_index, source_copy)
	return true


func used_slot_count(container_id: StringName = &"inventory") -> int:
	var used := 0
	for index: int in capacity(container_id):
		var slot := get_slot(container_id, index)
		if slot != null and not slot.is_empty():
			used += 1
	return used


func to_dict() -> Dictionary:
	var serialized_slots: Dictionary = {}
	for slot_id: StringName in slots.keys():
		var slot := slots[slot_id] as BackpackSlot
		if slot != null:
			serialized_slots[String(slot_id)] = slot.to_dict()
	return {
		"slots": serialized_slots,
		"toolbar": toolbar.map(func(value: StringName) -> String: return String(value)),
		"itembar": itembar.map(func(value: StringName) -> String: return String(value)),
		"inventory_capacity": inventory_capacity,
		"selected_toolbar_index": selected_toolbar_index,
		"selected_itembar_index": selected_itembar_index,
	}


static func from_dict(data: Dictionary) -> BackpackState:
	if not SerializationUtil.has_valid_dictionary(data, "slots"):
		return null
	if not SerializationUtil.has_valid_array(data, "toolbar") or not SerializationUtil.has_valid_array(data, "itembar"):
		return null
	if not SerializationUtil.has_valid_int(data, "inventory_capacity"):
		return null
	var toolbar_data := data.get("toolbar", []) as Array
	var itembar_data := data.get("itembar", []) as Array
	var restored := BackpackState.new(
		int(data.get("inventory_capacity", DEFAULT_INVENTORY_CAPACITY)),
		toolbar_data.size(),
		itembar_data.size()
	)
	restored.toolbar.clear()
	restored.itembar.clear()
	for value in toolbar_data:
		if typeof(value) != TYPE_STRING:
			return null
		restored.toolbar.append(StringName(str(value)))
	for value in itembar_data:
		if typeof(value) != TYPE_STRING:
			return null
		restored.itembar.append(StringName(str(value)))
	restored.slots.clear()
	for key: Variant in (data.get("slots", {}) as Dictionary).keys():
		var slot_data: Variant = (data.get("slots", {}) as Dictionary)[key]
		if typeof(slot_data) != TYPE_DICTIONARY:
			return null
		var slot := BackpackSlot.from_dict(slot_data as Dictionary)
		if slot == null:
			return null
		restored.slots[StringName(str(key))] = slot
	restored._ensure_layout(restored.toolbar.size(), restored.itembar.size())
	restored.selected_toolbar_index = clampi(int(data.get("selected_toolbar_index", 0)), 0, maxi(0, restored.toolbar.size() - 1))
	restored.selected_itembar_index = clampi(int(data.get("selected_itembar_index", 0)), 0, maxi(0, restored.itembar.size() - 1))
	return restored


func _ensure_layout(toolbar_capacity: int, itembar_capacity: int) -> void:
	toolbar.clear()
	itembar.clear()
	for index: int in maxi(0, toolbar_capacity):
		var slot_id := StringName("toolbar_%d" % index)
		toolbar.append(slot_id)
		if not slots.has(slot_id):
			slots[slot_id] = BackpackSlot.new(slot_id)
	for index: int in maxi(0, itembar_capacity):
		var slot_id := StringName("itembar_%d" % index)
		itembar.append(slot_id)
		if not slots.has(slot_id):
			slots[slot_id] = BackpackSlot.new(slot_id)
	for index: int in inventory_capacity:
		var slot_id := inventory_slot_id(index)
		if not slots.has(slot_id):
			slots[slot_id] = BackpackSlot.new(slot_id)


func _slot_id(container_id: StringName, index: int) -> StringName:
	if index < 0 or index >= capacity(container_id):
		return &""
	match container_id:
		&"inventory":
			return inventory_slot_id(index)
		&"toolbar":
			return toolbar[index]
		&"itembar":
			return itembar[index]
	return &""


func _free_space_for(container_id: StringName, item_id: StringName, stack_limit: int) -> int:
	var total := 0
	for index: int in capacity(container_id):
		var slot := get_slot(container_id, index)
		if slot == null or slot.is_empty():
			total += stack_limit
		elif slot.item_id == item_id and slot.amount < stack_limit:
			total += stack_limit - slot.amount
	return total
