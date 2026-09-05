class_name ItemManagerService
extends Node
const ITEM_SCENE := preload("res://scenes/items/item.tscn")
const PLANT_SCENE := preload("res://scenes/items/plants/plant.tscn")
const HARVESTABLE_SCENE := preload("res://scenes/items/harvestables/harvestable.tscn")

var pickups: Dictionary[StringName, Item] = {}
var _unique_count: int = 0


func get_unique_id(meta_id: StringName) -> StringName:
	if meta_id == &"":
		return &""
	_unique_count += 1
	return StringName("%s_%d" % [meta_id, _unique_count])


func reset_unique_count() -> void:
	_unique_count = 0


func register_pickup(item: Item) -> void:
	if item == null or item.item_id() == &"" or item.meta == null or not item.meta.can_pickup:
		return
	pickups[item.item_id()] = item


func unregister_pickup(item: Item) -> void:
	if item == null:
		return
	var item_id := item.item_id()
	if item_id != &"" and pickups.get(item_id, null) == item:
		pickups.erase(item_id)


func get_pickups() -> Array[Item]:
	var result: Array[Item] = []
	for item_id: StringName in pickups.keys():
		var item := pickups[item_id] as Item
		if item == null or not is_instance_valid(item) or item.meta == null or not item.meta.can_pickup:
			pickups.erase(item_id)
			continue
		result.append(item)
	return result


func register_unique_id(unique_id: StringName) -> void:
	var suffix := String(unique_id).get_slice("_", String(unique_id).get_slice_count("_") - 1)
	if suffix.is_valid_int():
		_unique_count = maxi(_unique_count, suffix.to_int())


func create_from_state(item_state: ItemState, parent: Node = null) -> Item:
	if item_state == null or item_state.unique_id == &"":
		return null
	var item_meta := DataCatalog.get_item(item_state.meta_id)
	if item_meta == null:
		return null
	register_unique_id(item_state.unique_id)
	var item: Item
	if item_meta is ToolMeta:
		item = Tool.new(item_state)
	elif item_meta is SeedMeta:
		item = Seed.new(item_state)
	elif item_state is PlantState or item_meta is PlantMeta:
		item = PLANT_SCENE.instantiate() as Item
	elif item_state is HarvestableState or item_meta is HarvestableMeta:
		item = HARVESTABLE_SCENE.instantiate() as Item
	else:
		item = ITEM_SCENE.instantiate() as Item
	if item == null:
		return null
	item.state = item_state
	item.meta = item_meta
	item.refresh_visual(item_meta.icon_texture, item_meta.visual_offset)
	item.name = item_state.unique_id
	if parent != null:
		parent.add_child(item)
	return item


func create_from_meta(item_meta: ItemMeta, parent: Node = null) -> Item:
	if item_meta == null or item_meta.id == &"" or item_meta is ToolMeta:
		return null
	var item_state: ItemState
	if item_meta is PlantMeta:
		item_state = PlantState.new()
		item_state.health = item_meta.health
	elif item_meta is HarvestableMeta:
		item_state = HarvestableState.new()
		item_state.health = item_meta.health
	elif item_meta.can_pickup:
		item_state = ItemState.new()
	else:
		return null
	item_state.unique_id = get_unique_id(item_meta.id)
	item_state.meta_id = item_meta.id
	return create_from_state(item_state, parent)


func create_from_id(item_id: StringName, parent: Node = null) -> Item:
	if item_id == &"":
		return null
	return create_from_meta(DataCatalog.get_item(item_id), parent)

