class_name PlayerState
extends Resource

enum ActiveHandSource {
	NONE,
	TOOLBAR,
	ITEMBAR,
}

@export var map_id: StringName = &"farm"
@export var spawn_id: StringName = &"default"
@export var cell: Vector2i = Vector2i(5, 4)
@export_enum("up", "down", "left", "right") var facing: String = "down"
@export_range(1, 999, 1) var max_health: int = 100
@export_range(0, 999, 1) var health: int = 100
@export_range(1, 999, 1) var max_stamina: int = 100
@export_range(0, 999, 1) var stamina: int = 100
@export_range(0, 999999, 1) var gold: int = 500
@export var active_hand_source: ActiveHandSource = ActiveHandSource.NONE
@export var backpack_state: BackpackState = BackpackState.new(20, 6, 10)


func initialize(template: PlayerState) -> Error:
	if template == null or template.backpack_state == null:
		return ERR_UNCONFIGURED
	template.backpack_state.ensure_layout()
	var restored := from_dict(template.to_dict())
	if restored == null:
		return ERR_INVALID_DATA
	_copy_from(restored)
	active_hand_source = ActiveHandSource.NONE
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


func active_stack() -> BackpackSlot:
	if backpack_state == null:
		return BackpackSlot.new()
	var selected := backpack_state.selected_slot(active_hand_source)
	return selected if selected != null else BackpackSlot.new()


func select_bar_relative(source: ActiveHandSource, offset: int) -> Error:
	if offset == 0 or backpack_state == null:
		return ERR_INVALID_PARAMETER
	var capacity := backpack_state.capacity(_container_for_source(source))
	if capacity == 0:
		return ERR_INVALID_PARAMETER
	var current := backpack_state.selected_toolbar_index if source == ActiveHandSource.TOOLBAR else backpack_state.selected_itembar_index
	return select_bar_index(source, wrapi(current + offset, 0, capacity))


func select_bar_index(source: ActiveHandSource, index: int) -> Error:
	if backpack_state == null or not backpack_state.select_bar_index(source, index):
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
	if backpack_state == null:
		return ERR_INVALID_PARAMETER
	var source := backpack_state.get_slot(source_id, source_index)
	var target := backpack_state.get_slot(target_id, target_index)
	if source == null or target == null:
		return ERR_INVALID_PARAMETER
	if source_id == target_id and source_index == target_index:
		return OK
	if not _container_accepts_slot(target_id, source, source_meta) or not _container_accepts_slot(source_id, target, target_meta):
		return ERR_UNAVAILABLE
	if not source.is_empty() and source.can_merge(target):
		if source_meta == null or source.amount + target.amount > source_meta.stack_limit:
			return ERR_UNAVAILABLE
		target.amount += source.amount
		source.clear()
		return OK
	if not backpack_state.switch_item(source_id, source_index, target_id, target_index):
		return ERR_CANT_ACQUIRE_RESOURCE
	return OK


func container_accepts_slot(container_id: StringName, slot: BackpackSlot, meta: ItemMeta) -> bool:
	return _container_accepts_slot(container_id, slot, meta)


func used_inventory_slots() -> int:
	return backpack_state.used_slot_count(&"inventory") if backpack_state != null else 0


func used_slot_count() -> int:
	if backpack_state == null:
		return 0
	return backpack_state.used_slot_count(&"inventory") + backpack_state.used_slot_count(&"toolbar") + backpack_state.used_slot_count(&"itembar")


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
		"backpack": backpack_state.to_dict() if backpack_state != null else {},
	}


static func from_dict(data: Dictionary) -> PlayerState:
	for key: String in ["map_id", "spawn_id", "facing"]:
		if not SerializationUtil.has_valid_string(data, key):
			return null
	for key: String in ["max_health", "health", "max_stamina", "stamina", "gold", "active_hand_source"]:
		if not SerializationUtil.has_valid_int(data, key):
			return null
	if not SerializationUtil.has_valid_vector2i(data, "cell") or not SerializationUtil.has_valid_dictionary(data, "backpack"):
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
	var restored_backpack := BackpackState.from_dict(data.get("backpack", {}) as Dictionary)
	if restored_backpack == null:
		return null
	restored_backpack.ensure_layout()
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
	restored.backpack_state = restored_backpack
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
	backpack_state = other.backpack_state


func _container_accepts_slot(container_id: StringName, slot: BackpackSlot, meta: ItemMeta) -> bool:
	if slot == null or slot.is_empty():
		return true
	if meta == null or meta.id != slot.item_id:
		return false
	return backpack_state.accepts(container_id, meta) if backpack_state != null else false


func _container_for_source(source: ActiveHandSource) -> StringName:
	if source == ActiveHandSource.TOOLBAR:
		return &"toolbar"
	if source == ActiveHandSource.ITEMBAR:
		return &"itembar"
	return &""
