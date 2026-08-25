class_name ItemManagerService
extends Node

const ITEM_SCENE := preload("res://scenes/items/item.tscn")
const PLANT_SCENE := preload("res://scenes/items/plants/plant.tscn")
const HARVESTABLE_SCENE := preload("res://scenes/items/harvestables/harvestable.tscn")

var item_names: Dictionary[ItemMeta, StringName] = {}
var _name_serials: Dictionary[StringName, int] = {}


func create_item(item_state: ItemState, parent: Node = null) -> Item:
	if item_state == null or item_state.instance_id == &"":
		return null
	var item_meta := DataCatalog.get_item(item_state.meta_id)
	if item_meta == null:
		return null
	var item := _instantiate_item(item_meta, item_state)
	if item == null:
		return null
	item.state = item_state
	item.meta = item_meta
	item.refresh_visual(item_meta.icon_texture, item_meta.visual_offset)
	item.name = _item_name(item_meta, item_state, parent)
	if parent != null:
		parent.add_child(item)
	return item


func _instantiate_item(item_meta: ItemMeta, item_state: ItemState) -> Item:
	if item_meta is ToolMeta:
		return Tool.new(item_state)
	if item_meta is SeedMeta:
		return Seed.new(item_state)
	if item_state is PlantState or item_meta is PlantMeta:
		return PLANT_SCENE.instantiate() as Item
	if item_state is HarvestableState or item_meta is HarvestableMeta:
		return HARVESTABLE_SCENE.instantiate() as Item
	return ITEM_SCENE.instantiate() as Item


func _item_name(item_meta: ItemMeta, item_state: ItemState, parent: Node) -> StringName:
	var base_name: StringName = item_names.get(item_meta, &"")
	if base_name == &"":
		base_name = item_meta.id
		item_names[item_meta] = base_name
	if item_state != null and item_state.instance_id != &"":
		return item_state.instance_id
	var serial := int(_name_serials.get(base_name, 0)) + 1
	var candidate := base_name if serial == 1 else StringName("%s_%d" % [base_name, serial])
	while parent != null and parent.has_node(NodePath(String(candidate))):
		serial += 1
		candidate = StringName("%s_%d" % [base_name, serial])
	_name_serials[base_name] = serial
	return candidate
