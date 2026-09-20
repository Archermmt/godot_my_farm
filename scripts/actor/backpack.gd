class_name PlayerBackpack
extends Node

enum ActiveHandSource { NONE, TOOLBAR, ITEMBAR }

var _items: Dictionary[StringName, Item] = {}
var slots: Dictionary[StringName, BackpackSlot] = {}
var toolbar: Array[StringName] = []
var itembar: Array[StringName] = []
var main_space: Array[StringName] = []
var selected_ids: Dictionary[StringName, StringName] = {}
var active_hand_source: ActiveHandSource = ActiveHandSource.NONE


func _ready() -> void:
	var config := DataCatalog.config
	if config == null:
		return
	slots.clear()
	toolbar.clear()
	itembar.clear()
	main_space.clear()
	selected_ids.clear()
	active_hand_source = ActiveHandSource.NONE
	for pair in [
		[&"main_space", config.backpack_main_space_capacity],
		[&"toolbar", config.backpack_toolbar_capacity],
		[&"itembar", config.backpack_itembar_capacity]
	]:
		var ids: Array[StringName] = _container_ids(pair[0])
		for index in maxi(0, int(pair[1])):
			var slot_id := StringName("%s_%d" % [pair[0], index])
			ids.append(slot_id)
			slots[slot_id] = BackpackSlot.new(slot_id)
		if not ids.is_empty():
			selected_ids[pair[0]] = ids[0]
	for slot_id: StringName in config.backpack_initial_slots:
		var slot := config.backpack_initial_slots[slot_id] as BackpackSlot
		if slot != null:
			slots[slot_id] = slot.duplicate_slot()
	sync_runtime_items()


func ensure_layout() -> void:
	for container_id: StringName in [&"main_space", &"toolbar", &"itembar"]:
		for slot_id: StringName in _container_ids(container_id):
			if not slots.has(slot_id):
				slots[slot_id] = BackpackSlot.new(slot_id)


func capacity(container_id: StringName) -> int:
	return _container_ids(container_id).size()


func count_item(container_id: StringName, item_id: StringName) -> int:
	var total := 0
	for index in capacity(container_id):
		var slot := get_slot(container_id, index)
		if slot != null and slot.item_id == item_id:
			total += slot.amount
	return total


func used_slot_count(container_id: StringName = &"main_space") -> int:
	var used := 0
	for index in capacity(container_id):
		var slot := get_slot(container_id, index)
		if slot != null and not slot.is_empty():
			used += 1
	return used


func set_slot(container_id: StringName, index: int, value: BackpackSlot) -> bool:
	var slot_id := _slot_id(container_id, index)
	if slot_id == &"":
		return false
	var replacement := value.duplicate_slot() if value != null else BackpackSlot.new(slot_id)
	replacement.slot_id = slot_id
	slots[slot_id] = replacement
	return true


func get_slot(container_id: StringName, index: int) -> BackpackSlot:
	return slots.get(_slot_id(container_id, index), null) as BackpackSlot


func _slot_id(container_id: StringName, index: int) -> StringName:
	var ids := _container_ids(container_id)
	if index < 0 or index >= ids.size():
		return &""
	return ids[index]


func add_item(container_id: StringName, item_id: StringName, amount: int, stack_limit: int) -> int:
	if item_id == &"" or amount <= 0 or stack_limit <= 0:
		return 0
	var accepted := mini(amount, _free_space_for(container_id, item_id, stack_limit))
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


func accepts(container_id: StringName, meta: ItemMeta) -> bool:
	if meta == null:
		return false
	if container_id == &"toolbar":
		return meta is ToolMeta
	if container_id == &"itembar":
		return not meta is ToolMeta and not meta is HarvestableMeta
	return container_id == &"main_space"


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
			_compact_after_removal(container_id)
			return true
	return false


func switch_item(
	source_id: StringName,
	source_index: int,
	target_id: StringName,
	target_index: int
) -> Error:
	var source := get_slot(source_id, source_index)
	var target := get_slot(target_id, target_index)
	if source == null or target == null:
		return ERR_INVALID_PARAMETER
	var source_meta := DataCatalog.get_item(source.item_id) if not source.is_empty() else null
	var target_meta := DataCatalog.get_item(target.item_id) if not target.is_empty() else null
	if source_id == target_id and source_index == target_index:
		return OK
	if not _can_accept(target_id, source, source_meta) or not _can_accept(source_id, target, target_meta):
		return ERR_UNAVAILABLE
	if not source.is_empty() and source.can_merge(target):
		if source_meta == null or source.amount + target.amount > source_meta.stack_limit:
			return ERR_UNAVAILABLE
		target.amount += source.amount
		source.clear()
		_emit_container_changed(source_id, target_id)
		return OK
	var source_copy := source.duplicate_slot()
	var target_copy := target.duplicate_slot()
	set_slot(source_id, source_index, target_copy)
	set_slot(target_id, target_index, source_copy)
	_emit_container_changed(source_id, target_id)
	return OK


func _can_accept(container_id: StringName, slot: BackpackSlot, meta: ItemMeta) -> bool:
	if slot == null:
		return false
	if meta == null:
		return slot.is_empty()
	if not accepts(container_id, meta):
		return false
	return slot.is_empty() or meta.id == slot.item_id


func active_item() -> Item:
	var backpack_slot := active_slot()
	if backpack_slot != null and not backpack_slot.is_empty():
		return item_for_slot(backpack_slot)
	return null


func active_slot() -> BackpackSlot:
	var container_id := (
		&"toolbar"
		if active_hand_source == PlayerBackpack.ActiveHandSource.TOOLBAR
		else &"itembar" if active_hand_source == PlayerBackpack.ActiveHandSource.ITEMBAR else &""
	)
	var selected_id: StringName = selected_ids.get(container_id, &"")
	return slots.get(selected_id, null) as BackpackSlot


func selected_index(container_id: StringName) -> int:
	var selected_id: StringName = selected_ids.get(container_id, &"")
	return _container_ids(container_id).find(selected_id)


func select_bar_index(source: PlayerBackpack.ActiveHandSource, index: int) -> bool:
	var container_id := _container_id_for_source(source)
	var ids := _container_ids(container_id)
	if index < 0 or index >= ids.size():
		return false
	selected_ids[container_id] = ids[index]
	active_hand_source = source as ActiveHandSource
	_emit_selection_changed()
	return true


func select_bar_relative(source: PlayerBackpack.ActiveHandSource, offset: int) -> Error:
	if offset == 0:
		return ERR_INVALID_PARAMETER
	var container_id := _container_id_for_source(source)
	var ids := _container_ids(container_id)
	if ids.is_empty():
		return ERR_INVALID_PARAMETER
	var current := selected_index(container_id)
	if current < 0:
		current = 0
	for _step: int in ids.size():
		current = wrapi(current + offset, 0, ids.size())
		var slot := get_slot(container_id, current)
		if slot == null or slot.is_empty():
			continue
		if select_bar_index(source, current):
			return OK
	return ERR_DOES_NOT_EXIST


func _emit_selection_changed() -> void:
	var container_id := _container_id_for_source(active_hand_source)
	EventBus.bar_selection_changed.emit(int(active_hand_source), selected_index(container_id))
	var slot := active_slot()
	EventBus.active_hand_changed.emit(
		int(active_hand_source),
		slot.item_id if slot != null and not slot.is_empty() else &"",
		slot.amount if slot != null and not slot.is_empty() else 0
	)


func _emit_container_changed(source_id: StringName, target_id: StringName) -> void:
	EventBus.container_changed.emit(source_id)
	if source_id != target_id:
		EventBus.container_changed.emit(target_id)
	_emit_selection_changed()


func item_for_slot(slot: BackpackSlot) -> Item:
	if slot == null or slot.is_empty():
		return null
	var meta := DataCatalog.get_item(slot.item_id)
	if meta == null or (not meta is ToolMeta and not meta is SeedMeta):
		return null
	var cached := _items.get(meta.id, null) as Item
	if cached != null and is_instance_valid(cached):
		return cached
	var item := ItemManager.create_from_meta(meta, self)
	if item == null:
		return null
	_items[meta.id] = item
	return item


func sync_runtime_items() -> void:
	var available: Dictionary[StringName, bool] = {}
	for container_id: StringName in [&"toolbar", &"itembar", &"main_space"]:
		for index: int in capacity(container_id):
			var slot := get_slot(container_id, index)
			if slot == null or slot.is_empty():
				continue
			var meta := DataCatalog.get_item(slot.item_id)
			if meta is ToolMeta or meta is SeedMeta:
				available[slot.item_id] = true
	for item_id: StringName in _items.keys():
		if not available.has(item_id):
			_remove_item(item_id)


func _container_id_for_source(source: PlayerBackpack.ActiveHandSource) -> StringName:
	if source == PlayerBackpack.ActiveHandSource.TOOLBAR:
		return &"toolbar"
	if source == PlayerBackpack.ActiveHandSource.ITEMBAR:
		return &"itembar"
	return &""


func _container_ids(container_id: StringName) -> Array[StringName]:
	match container_id:
		&"main_space":
			return main_space
		&"toolbar":
			return toolbar
		&"itembar":
			return itembar
	return []


func _free_space_for(container_id: StringName, item_id: StringName, stack_limit: int) -> int:
	var total := 0
	for index: int in capacity(container_id):
		var slot := get_slot(container_id, index)
		if slot == null or slot.is_empty():
			total += stack_limit
		elif slot.item_id == item_id and slot.amount < stack_limit:
			total += stack_limit - slot.amount
	return total


func _compact_after_removal(container_id: StringName) -> void:
	if container_id != &"itembar" and container_id != &"main_space":
		return
	var occupied: Array[BackpackSlot] = []
	for index: int in capacity(container_id):
		var slot := get_slot(container_id, index)
		if slot != null and not slot.is_empty():
			occupied.append(slot.duplicate_slot())
	for index: int in capacity(container_id):
		var target := get_slot(container_id, index)
		if target == null:
			continue
		if index < occupied.size():
			target.item_id = occupied[index].item_id
			target.amount = occupied[index].amount
		else:
			target.clear()


func _remove_item(item_id: StringName) -> void:
	var item := _items.get(item_id, null) as Item
	_items.erase(item_id)
	if item != null and is_instance_valid(item):
		item.queue_free()


func to_dict() -> Dictionary:
	var serialized_slots: Dictionary = {}
	for slot_id: StringName in slots:
		var slot := slots[slot_id] as BackpackSlot
		if slot != null:
			serialized_slots[String(slot_id)] = slot.to_dict()
	return {
		"slots": serialized_slots,
		"toolbar": toolbar.map(func(v): return String(v)),
		"itembar": itembar.map(func(v): return String(v)),
		"main_space": main_space.map(func(v): return String(v)),
		"selected_ids":
		{"toolbar": String(selected_ids.get(&"toolbar", &"")), "itembar": String(selected_ids.get(&"itembar", &""))},
		"active_hand_source": int(active_hand_source)
	}


func from_dict(data: Dictionary) -> Error:
	if (
		not SerializationUtil.has_valid_dictionary(data, "slots")
		or not SerializationUtil.has_valid_array(data, "toolbar")
		or not SerializationUtil.has_valid_array(data, "itembar")
		or not SerializationUtil.has_valid_array(data, "main_space")
		or not SerializationUtil.has_valid_dictionary(data, "selected_ids")
		or not SerializationUtil.has_valid_int(data, "active_hand_source")
	):
		return ERR_INVALID_DATA
	var source := int(data.active_hand_source)
	if source < ActiveHandSource.NONE or source > ActiveHandSource.ITEMBAR:
		return ERR_INVALID_DATA
	toolbar.clear()
	itembar.clear()
	main_space.clear()
	slots.clear()
	selected_ids.clear()
	for pair in [[&"toolbar", toolbar], [&"itembar", itembar], [&"main_space", main_space]]:
		for value: Variant in data[pair[0]]:
			if typeof(value) != TYPE_STRING:
				return ERR_INVALID_DATA
			pair[1].append(StringName(str(value)))
	for key: Variant in data.slots as Dictionary:
		var slot := BackpackSlot.from_dict(data.slots[key] as Dictionary)
		if slot == null:
			return ERR_INVALID_DATA
		slots[StringName(str(key))] = slot
	for id: StringName in [&"toolbar", &"itembar"]:
		selected_ids[id] = StringName(str((data.selected_ids as Dictionary).get(String(id), "")))
	active_hand_source = source
	ensure_layout()
	sync_runtime_items()
	return OK
