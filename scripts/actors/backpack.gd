class_name PlayerBackpack
extends Node

var _items: Dictionary[StringName, Item] = {}
var backpack_state: BackpackState = null


func get_slot(container_id: StringName, index: int) -> BackpackSlot:
	return backpack_state.get_slot(container_id, index) if backpack_state != null else null


func add_item(container_id: StringName, item_id: StringName, amount: int, stack_limit: int) -> int:
	if backpack_state == null:
		return 0
	if item_id == &"" or amount <= 0 or stack_limit <= 0:
		return 0
	var accepted := mini(amount, _free_space_for(container_id, item_id, stack_limit))
	var remaining := accepted
	for index: int in backpack_state.capacity(container_id):
		var slot := get_slot(container_id, index)
		if slot != null and not slot.is_empty() and slot.item_id == item_id and slot.amount < stack_limit:
			var moved := mini(remaining, stack_limit - slot.amount)
			slot.amount += moved
			remaining -= moved
			if remaining == 0:
				return accepted
	for index: int in backpack_state.capacity(container_id):
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
		return meta.is_tool()
	if container_id == &"itembar":
		return not meta.is_tool() and not meta is HarvestableMeta
	return container_id == &"main_space"


func remove_item(container_id: StringName, item_id: StringName, amount: int) -> bool:
	if backpack_state == null or item_id == &"" or amount <= 0 or backpack_state.count_item(container_id, item_id) < amount:
		return false
	var remaining := amount
	for index: int in backpack_state.capacity(container_id):
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
	source_container: StringName, source_index: int, target_container: StringName, target_index: int
) -> bool:
	if backpack_state == null:
		return false
	var source := get_slot(source_container, source_index)
	var target := get_slot(target_container, target_index)
	if source == null or target == null:
		return false
	var source_copy := source.duplicate_slot()
	var target_copy := target.duplicate_slot()
	backpack_state.set_slot(source_container, source_index, target_copy)
	backpack_state.set_slot(target_container, target_index, source_copy)
	return true


func exchange_container_slots(
	source_id: StringName,
	source_index: int,
	target_id: StringName,
	target_index: int,
	source_meta: ItemMeta = null,
	target_meta: ItemMeta = null
) -> Error:
	if backpack_state == null:
		return ERR_INVALID_PARAMETER
	var source := get_slot(source_id, source_index)
	var target := get_slot(target_id, target_index)
	if source == null or target == null:
		return ERR_INVALID_PARAMETER
	if source_meta == null and not source.is_empty():
		source_meta = DataCatalog.get_item(source.item_id)
	if target_meta == null and not target.is_empty():
		target_meta = DataCatalog.get_item(target.item_id)
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
	var result := OK if switch_item(source_id, source_index, target_id, target_index) else ERR_CANT_ACQUIRE_RESOURCE
	if result == OK:
		_emit_container_changed(source_id, target_id)
	return result


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
	if backpack_state == null:
		return null
	var container_id := (
		&"toolbar"
		if backpack_state.active_hand_source == BackpackState.ActiveHandSource.TOOLBAR
		else &"itembar" if backpack_state.active_hand_source == BackpackState.ActiveHandSource.ITEMBAR else &""
	)
	var selected_id: StringName = backpack_state.selected_ids.get(container_id, &"")
	return backpack_state.slots.get(selected_id, null) as BackpackSlot


func selected_index(container_id: StringName) -> int:
	if backpack_state == null:
		return -1
	var selected_id: StringName = backpack_state.selected_ids.get(container_id, &"")
	return _container_ids(container_id).find(selected_id)


func select_bar_index(source: BackpackState.ActiveHandSource, index: int) -> bool:
	if backpack_state == null:
		return false
	var container_id := _container_id_for_source(source)
	var ids := _container_ids(container_id)
	if index < 0 or index >= ids.size():
		return false
	backpack_state.selected_ids[container_id] = ids[index]
	backpack_state.active_hand_source = source
	_emit_selection_changed()
	return true


func select_bar_relative(source: BackpackState.ActiveHandSource, offset: int) -> Error:
	if backpack_state == null or offset == 0:
		return ERR_INVALID_PARAMETER
	var container_id := _container_id_for_source(source)
	var ids := _container_ids(container_id)
	if ids.is_empty():
		return ERR_INVALID_PARAMETER
	var current := selected_index(container_id)
	if current < 0:
		current = 0
	if not select_bar_index(source, wrapi(current + offset, 0, ids.size())):
		return ERR_INVALID_PARAMETER
	return OK


func _emit_selection_changed() -> void:
	if backpack_state == null:
		return
	var container_id := _container_id_for_source(backpack_state.active_hand_source)
	EventBus.bar_selection_changed.emit(int(backpack_state.active_hand_source), selected_index(container_id))
	var slot := active_slot()
	EventBus.active_hand_changed.emit(
		int(backpack_state.active_hand_source),
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
	var item_state := ItemState.new()
	item_state.instance_id = meta.id
	item_state.meta_id = meta.id
	var item := ItemManager.create_item(item_state, self)
	if item == null:
		return null
	_items[meta.id] = item
	return item


func setup(next_state: BackpackState) -> Error:
	if next_state == null:
		return ERR_INVALID_PARAMETER
	backpack_state = next_state
	sync_runtime_items()
	return OK


func sync_runtime_items() -> void:
	var available: Dictionary[StringName, bool] = {}
	if backpack_state != null:
		for container_id: StringName in [&"toolbar", &"itembar", &"main_space"]:
			for index: int in backpack_state.capacity(container_id):
				var slot := backpack_state.get_slot(container_id, index)
				if slot == null or slot.is_empty():
					continue
				var meta := DataCatalog.get_item(slot.item_id)
				if meta is ToolMeta or meta is SeedMeta:
					available[slot.item_id] = true
	for item_id: StringName in _items.keys():
		if not available.has(item_id):
			_remove_item(item_id)


func _container_id_for_source(source: BackpackState.ActiveHandSource) -> StringName:
	if source == BackpackState.ActiveHandSource.TOOLBAR:
		return &"toolbar"
	if source == BackpackState.ActiveHandSource.ITEMBAR:
		return &"itembar"
	return &""


func _container_ids(container_id: StringName) -> Array[StringName]:
	if backpack_state == null:
		var empty: Array[StringName] = []
		return empty
	match container_id:
		&"main_space":
			return backpack_state.main_space
		&"toolbar":
			return backpack_state.toolbar
		&"itembar":
			return backpack_state.itembar
	var empty: Array[StringName] = []
	return empty


func _free_space_for(container_id: StringName, item_id: StringName, stack_limit: int) -> int:
	var total := 0
	for index: int in backpack_state.capacity(container_id):
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
	for index: int in backpack_state.capacity(container_id):
		var slot := get_slot(container_id, index)
		if slot != null and not slot.is_empty():
			occupied.append(slot.duplicate_slot())
	for index: int in backpack_state.capacity(container_id):
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
