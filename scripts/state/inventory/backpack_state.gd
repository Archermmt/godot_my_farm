class_name BackpackState
extends Resource

enum ActiveHandSource { NONE, TOOLBAR, ITEMBAR }

var slots: Dictionary[StringName, BackpackSlot] = {}
var toolbar: Array[StringName] = []
var itembar: Array[StringName] = []
var main_space: Array[StringName] = []
var selected_ids: Dictionary[StringName, StringName] = {}
var active_hand_source: ActiveHandSource = ActiveHandSource.NONE


func _init(p_main_space_capacity: int = 20, p_toolbar_capacity: int = 6, p_itembar_capacity: int = 10) -> void:
	var capacities: Dictionary[StringName, int] = {
		&"main_space": maxi(0, p_main_space_capacity),
		&"toolbar": maxi(0, p_toolbar_capacity),
		&"itembar": maxi(0, p_itembar_capacity),
	}
	for container_id: StringName in capacities:
		var container_slots := _container_slots(container_id)
		container_slots.clear()
		for index: int in capacities[container_id]:
			var slot_id := StringName("%s_%d" % [container_id, index])
			container_slots.append(slot_id)
			if not slots.has(slot_id):
				slots[slot_id] = BackpackSlot.new(slot_id)
		if not container_slots.is_empty() and not container_slots.has(selected_ids.get(container_id, &"")):
			selected_ids[container_id] = container_slots[0]


func ensure_layout() -> void:
	for container_id: StringName in [&"main_space", &"toolbar", &"itembar"]:
		var container_slots := _container_slots(container_id)
		for slot_id: StringName in container_slots:
			if not slots.has(slot_id):
				slots[slot_id] = BackpackSlot.new(slot_id)
		if not container_slots.is_empty() and not container_slots.has(selected_ids.get(container_id, &"")):
			selected_ids[container_id] = container_slots[0]


func capacity(container_id: StringName) -> int:
	match container_id:
		&"main_space":
			return main_space.size()
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


func count_item(container_id: StringName, item_id: StringName) -> int:
	var total := 0
	for index: int in capacity(container_id):
		var slot := get_slot(container_id, index)
		if slot != null and slot.item_id == item_id:
			total += slot.amount
	return total


func used_slot_count(container_id: StringName = &"main_space") -> int:
	var used := 0
	for index: int in capacity(container_id):
		var slot := get_slot(container_id, index)
		if slot != null and not slot.is_empty():
			used += 1
	return used


func _slot_id(container_id: StringName, index: int) -> StringName:
	var container_slots := _container_slots(container_id)
	if index < 0 or index >= container_slots.size():
		return &""
	return container_slots[index]


func _container_slots(container_id: StringName) -> Array[StringName]:
	match container_id:
		&"main_space":
			return main_space
		&"toolbar":
			return toolbar
		&"itembar":
			return itembar
	return []


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
		"main_space": main_space.map(func(value: StringName) -> String: return String(value)),
		"selected_ids":
		{
			"toolbar": String(selected_ids.get(&"toolbar", &"")),
			"itembar": String(selected_ids.get(&"itembar", &"")),
		},
		"active_hand_source": int(active_hand_source),
	}


static func from_dict(data: Dictionary) -> BackpackState:
	if not SerializationUtil.has_valid_dictionary(data, "slots"):
		return null
	if (
		not SerializationUtil.has_valid_array(data, "toolbar")
		or not SerializationUtil.has_valid_array(data, "itembar")
		or not SerializationUtil.has_valid_array(data, "main_space")
		or not SerializationUtil.has_valid_dictionary(data, "selected_ids")
	):
		return null
	if not SerializationUtil.has_valid_int(data, "active_hand_source"):
		return null
	var restored_source := int(data.get("active_hand_source", ActiveHandSource.NONE))
	if restored_source < ActiveHandSource.NONE or restored_source > ActiveHandSource.ITEMBAR:
		return null
	var toolbar_data := data.get("toolbar", []) as Array
	var itembar_data := data.get("itembar", []) as Array
	var main_space_data := data.get("main_space", []) as Array
	var restored := BackpackState.new(main_space_data.size(), toolbar_data.size(), itembar_data.size())
	restored.toolbar.clear()
	restored.itembar.clear()
	restored.main_space.clear()
	for value: Variant in toolbar_data:
		if typeof(value) != TYPE_STRING:
			return null
		restored.toolbar.append(StringName(str(value)))
	for value: Variant in itembar_data:
		if typeof(value) != TYPE_STRING:
			return null
		restored.itembar.append(StringName(str(value)))
	for value: Variant in main_space_data:
		if typeof(value) != TYPE_STRING:
			return null
		restored.main_space.append(StringName(str(value)))
	restored.slots.clear()
	for key: Variant in (data.get("slots", {}) as Dictionary).keys():
		var slot_data: Variant = (data.get("slots", {}) as Dictionary)[key]
		if typeof(slot_data) != TYPE_DICTIONARY:
			return null
		var slot := BackpackSlot.from_dict(slot_data as Dictionary)
		if slot == null:
			return null
		restored.slots[StringName(str(key))] = slot
	restored.ensure_layout()
	var restored_selected_ids := data.get("selected_ids", {}) as Dictionary
	for container_id: StringName in [&"toolbar", &"itembar"]:
		if not SerializationUtil.has_valid_string(restored_selected_ids, String(container_id)):
			return null
		var selected_id := StringName(str(restored_selected_ids.get(String(container_id), "")))
		var container_slots := restored._container_slots(container_id)
		if (
			(container_slots.is_empty() and selected_id != &"")
			or (not container_slots.is_empty() and not container_slots.has(selected_id))
		):
			return null
		restored.selected_ids[container_id] = selected_id
	restored.active_hand_source = restored_source
	return restored
