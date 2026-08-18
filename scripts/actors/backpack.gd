class_name PlayerBackpack
extends Node

var _items: Dictionary[StringName, Item] = {}
var backpack_state: BackpackState = null


func bind_state(next_state: BackpackState) -> void:
	backpack_state = next_state


func get_slot(container_id: StringName, index: int) -> BackpackSlot:
	return backpack_state.get_slot(container_id, index) if backpack_state != null else null


func add_item(container_id: StringName, item_id: StringName, amount: int, stack_limit: int) -> int:
	if backpack_state == null:
		return 0
	return backpack_state.add_item_partial(container_id, item_id, amount, stack_limit)


func remove_item(container_id: StringName, item_id: StringName, amount: int) -> bool:
	return backpack_state != null and backpack_state.remove_item(container_id, item_id, amount)


func switch_item(source_container: StringName, source_index: int, target_container: StringName, target_index: int) -> bool:
	return backpack_state != null and backpack_state.switch_item(source_container, source_index, target_container, target_index)


func active_item(player_state: PlayerState) -> Item:
	if player_state == null:
		return null
	if backpack_state == null:
		bind_state(player_state.backpack_state)
	var backpack_slot := backpack_state.selected_slot(player_state.active_hand_source) if backpack_state != null else null
	if backpack_slot != null and not backpack_slot.is_empty():
		return item_for_slot(backpack_slot)
	var stack := player_state.active_stack()
	if stack == null or stack.is_empty():
		return null
	var meta := DataCatalog.get_item(stack.item_id)
	return item_for_meta(meta)


func item_for_meta(meta: ItemMeta) -> Item:
	if not meta is ToolMeta and not meta is SeedMeta:
		return null
	var cached := _items.get(meta.id, null) as Item
	if cached != null and is_instance_valid(cached):
		return cached
	var item: Item
	if meta is ToolMeta:
		item = Tool.new(meta as ToolMeta)
	elif meta is SeedMeta:
		item = Seed.new(meta as SeedMeta)
	if item == null:
		return null
	item.name = String(meta.id)
	_items[meta.id] = item
	add_child(item)
	return item


func item_for_slot(slot: BackpackSlot) -> Item:
	if slot == null or slot.is_empty():
		return null
	var meta := DataCatalog.get_item(slot.item_id)
	var item := item_for_meta(meta)
	return item


func sync_from_player_state(player_state: PlayerState) -> void:
	if player_state != null:
		bind_state(player_state.backpack_state)
	var available: Dictionary[StringName, bool] = {}
	if player_state != null:
		for container_id: StringName in [&"toolbar", &"itembar", &"inventory"]:
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


func _remove_item(item_id: StringName) -> void:
	var item := _items.get(item_id, null) as Item
	_items.erase(item_id)
	if item != null and is_instance_valid(item):
		item.queue_free()
