class_name PlayerState
extends Resource

enum ActiveHandSource {
	NONE,
	TOOLBAR,
	ITEMBAR,
}

@export var map_id: StringName = &"cabin"
@export var spawn_id: StringName = &"wake"
@export var cell: Vector2i = Vector2i(5, 4)
@export_enum("up", "down", "left", "right") var facing: String = "down"
@export_range(1, 999, 1) var max_health: int = 100
@export_range(0, 999, 1) var health: int = 100
@export_range(1, 999, 1) var max_stamina: int = 100
@export_range(0, 999, 1) var stamina: int = 100
@export_range(0, 999999, 1) var gold: int = 500
@export var active_hand_source: ActiveHandSource = ActiveHandSource.NONE
@export var inventory: InventoryState = InventoryState.new(20, &"inventory")
@export var toolbar: ToolbarState = ToolbarState.new(6)
@export var itembar: ItembarState = ItembarState.new(10)


func initialize(template: PlayerState, catalog: DataCatalogService) -> Error:
	if template == null or template.inventory == null or template.toolbar == null or template.itembar == null or catalog == null or not catalog.is_ready_for_game():
		return ERR_UNCONFIGURED
	var restored := from_dict(template.to_dict())
	if restored == null:
		return ERR_INVALID_DATA
	_copy_from(restored)
	active_hand_source = ActiveHandSource.NONE
	for container_id: StringName in [&"inventory", &"toolbar", &"itembar"]:
		var container := get_container(container_id)
		for stack: ItemStack in container.slots:
			var item_meta := catalog.get_item(stack.item_id) if not stack.is_empty() else null
			if not container_accepts_stack(container_id, stack, item_meta):
				return ERR_INVALID_DATA
	return OK


func set_health(value: int) -> void:
	health = clampi(value, 0, max(1, max_health))


func set_stamina(value: int) -> void:
	stamina = clampi(value, 0, max(1, max_stamina))


func consume_energy(amount: int) -> bool:
	if amount < 0 or stamina < amount:
		return false
	stamina -= amount
	return true


func restore_for_new_day() -> void:
	health = max_health
	stamina = max_stamina


func set_gold(value: int) -> void:
	gold = max(0, value)


func set_max_health(value: int) -> void:
	max_health = max(1, value)
	set_health(health)


func set_max_stamina(value: int) -> void:
	max_stamina = max(1, value)
	set_stamina(stamina)


func get_container(container_id: StringName) -> InventoryState:
	match container_id:
		&"inventory":
			return inventory
		&"toolbar":
			return toolbar
		&"itembar":
			return itembar
	return null


func active_stack() -> ItemStack:
	match active_hand_source:
		ActiveHandSource.TOOLBAR:
			return toolbar.selected_stack()
		ActiveHandSource.ITEMBAR:
			return itembar.selected_stack()
	return ItemStack.new()


func select_bar_relative(source: ActiveHandSource, offset: int) -> Error:
	if offset == 0:
		return ERR_INVALID_PARAMETER
	var container := _bar_for_source(source)
	if container == null or container.capacity() == 0:
		return ERR_INVALID_PARAMETER
	return select_bar_index(source, wrapi(container.selected_index + offset, 0, container.capacity()))


func select_bar_index(source: ActiveHandSource, index: int) -> Error:
	var container := _bar_for_source(source)
	if container == null or not container.select_slot(index):
		return ERR_INVALID_PARAMETER
	active_hand_source = source
	return OK


func exchange_container_slots(
	source_id: StringName,
	source_index: int,
	target_id: StringName,
	target_index: int,
	source_meta: ItemMeta,
	target_meta: ItemMeta
) -> Error:
	var source := get_container(source_id)
	var target := get_container(target_id)
	if source == null or target == null:
		return ERR_INVALID_PARAMETER
	var source_stack := source.get_slot(source_index)
	var target_stack := target.get_slot(target_index)
	if source_stack == null or target_stack == null:
		return ERR_INVALID_PARAMETER
	if source == target and source_index == target_index:
		return OK
	if not container_accepts_stack(target_id, source_stack, source_meta) or not container_accepts_stack(source_id, target_stack, target_meta):
		return ERR_UNAVAILABLE
	if not source_stack.is_empty() and source_stack.can_merge(target_stack):
		if source_meta == null or source_stack.amount + target_stack.amount > source_meta.stack_limit:
			return ERR_UNAVAILABLE
		target_stack.amount += source_stack.amount
		source_stack.clear()
	else:
		var source_copy := source_stack.duplicate_stack()
		var target_copy := target_stack.duplicate_stack()
		if not source.set_slot(source_index, target_copy) or not target.set_slot(target_index, source_copy):
			return ERR_CANT_ACQUIRE_RESOURCE
	return OK


func container_accepts_stack(container_id: StringName, stack: ItemStack, meta: ItemMeta) -> bool:
	if stack == null or stack.is_empty():
		return true
	if meta == null or meta.id != stack.item_id:
		return false
	match container_id:
		&"inventory":
			return true
		&"toolbar":
			return toolbar.accepts(meta)
		&"itembar":
			return itembar.accepts(meta)
	return false


func used_inventory_slots() -> int:
	return _used_slots(inventory)


func used_slot_count() -> int:
	return _used_slots(inventory) + _used_slots(toolbar) + _used_slots(itembar)


func to_dict() -> Dictionary:
	return {
		"map_id": String(map_id),
		"spawn_id": String(spawn_id),
		"cell": SerializationUtil.vector2i_to_dict(cell),
		"facing": String(facing),
		"max_health": max_health,
		"health": health,
		"max_stamina": max_stamina,
		"stamina": stamina,
		"gold": gold,
		"active_hand_source": int(active_hand_source),
		"inventory": inventory.to_dict(),
		"toolbar": toolbar.to_dict(),
		"itembar": itembar.to_dict(),
	}


static func from_dict(data: Dictionary) -> PlayerState:
	for key: String in ["map_id", "spawn_id", "facing"]:
		if not SerializationUtil.has_valid_string(data, key):
			return null
	for key: String in ["max_health", "health", "max_stamina", "stamina", "gold", "active_hand_source"]:
		if not SerializationUtil.has_valid_int(data, key):
			return null
	if not SerializationUtil.has_valid_vector2i(data, "cell"):
		return null
	for key: String in ["inventory", "toolbar", "itembar"]:
		if not SerializationUtil.has_valid_dictionary(data, key):
			return null
	if int(data.get("max_health", 100)) <= 0 or int(data.get("max_stamina", 100)) <= 0:
		return null
	if int(data.get("health", 100)) < 0 or int(data.get("stamina", 100)) < 0 or int(data.get("gold", 0)) < 0:
		return null
	if str(data.get("facing", "")) not in ["up", "down", "left", "right"]:
		return null
	var restored_source := int(data.get("active_hand_source", ActiveHandSource.NONE)) as ActiveHandSource
	if restored_source < ActiveHandSource.NONE or restored_source > ActiveHandSource.ITEMBAR:
		return null
	var restored := PlayerState.new()
	restored.map_id = StringName(str(data.get("map_id", "farm")))
	restored.spawn_id = StringName(str(data.get("spawn_id", "default")))
	restored.cell = SerializationUtil.vector2i_from_dict(data.get("cell", {}) as Dictionary)
	restored.facing = str(data.get("facing", "down"))
	restored.set_max_health(int(data.get("max_health", 100)))
	restored.set_health(int(data.get("health", restored.max_health)))
	restored.set_max_stamina(int(data.get("max_stamina", 100)))
	restored.set_stamina(int(data.get("stamina", restored.max_stamina)))
	restored.set_gold(int(data.get("gold", 0)))
	restored.active_hand_source = restored_source
	var restored_inventory := InventoryState.from_dict(data.get("inventory", {}) as Dictionary)
	var restored_toolbar := ToolbarState.from_dict(data.get("toolbar", {}) as Dictionary)
	var restored_itembar := ItembarState.from_dict(data.get("itembar", {}) as Dictionary)
	if restored_inventory == null or restored_toolbar == null or restored_itembar == null:
		return null
	if restored_inventory.owner_id != &"inventory":
		return null
	restored.inventory = restored_inventory
	restored.toolbar = restored_toolbar
	restored.itembar = restored_itembar
	return restored


func _copy_from(other: PlayerState) -> void:
	map_id = other.map_id
	spawn_id = other.spawn_id
	cell = other.cell
	facing = other.facing
	max_health = other.max_health
	health = other.health
	max_stamina = other.max_stamina
	stamina = other.stamina
	gold = other.gold
	active_hand_source = other.active_hand_source
	inventory = other.inventory
	toolbar = other.toolbar
	itembar = other.itembar


func _bar_for_source(source: ActiveHandSource) -> InventoryState:
	if source == ActiveHandSource.TOOLBAR:
		return toolbar
	if source == ActiveHandSource.ITEMBAR:
		return itembar
	return null


func _used_slots(container: InventoryState) -> int:
	var used := 0
	for stack: ItemStack in container.slots:
		if not stack.is_empty():
			used += 1
	return used
