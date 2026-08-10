class_name ItemManagerService
extends Node
const ITEM_SCENE := preload("res://scenes/items/item.tscn")
const PLANT_SCENE := preload("res://scenes/items/plants/plant.tscn")
const HARVESTABLE_SCENE := preload("res://scenes/items/harvestables/harvestable.tscn")
const ITEM_TOOL_SCENE := preload("res://scenes/items/tools/item_tool.tscn")
const CELL_TOOL_SCENE := preload("res://scenes/items/tools/cell_tool.tscn")
const SEED_SCRIPT := preload("res://scripts/item/tool/seed.gd")
const BASKET_SCRIPT := preload("res://scripts/item/tool/basket.gd")
const TOOL_SCRIPTS := {
	&"hoe": preload("res://scripts/item/tool/hoe.gd"),
	&"watering_can": preload("res://scripts/item/tool/watering_can.gd"),
	&"axe": preload("res://scripts/item/tool/axe.gd"),
	&"pickaxe": preload("res://scripts/item/tool/pickaxe.gd"),
	&"sickle": preload("res://scripts/item/tool/sickle.gd")
}
const HARVESTABLE_SCENES: Dictionary[StringName, PackedScene] = {
	&"stone": preload("res://scenes/items/harvestables/stone.tscn"),
	&"rock": preload("res://scenes/items/harvestables/stone.tscn"),
	&"grass": preload("res://scenes/items/harvestables/grass.tscn"),
	&"tree": preload("res://scenes/items/harvestables/tree.tscn"),
	&"stump": preload("res://scenes/items/harvestables/trunk.tscn"),
}

var pickups: Dictionary[StringName, Item] = {}
var harvestables: Dictionary[StringName, Harvestable] = {}
var _unique_count: int = 0


func get_unique_id(meta_id: StringName) -> StringName:
	if meta_id == &"":
		return &""
	_unique_count += 1
	return StringName("%s_%d" % [meta_id, _unique_count])


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


func register_harvestable(item: Harvestable, tool: ItemTool = null) -> void:
	var item_meta := item.meta as HarvestableMeta if item != null else null
	var tool_meta := tool.meta as ToolMeta if tool != null else null
	if (
		item != null
		and item.item_id() != &""
		and (tool_meta == null or (item_meta != null and item_meta.required_tool == tool_meta.tool_kind))
	):
		harvestables[item.item_id()] = item


func unregister_harvestable(item: Harvestable) -> void:
	if item != null and harvestables.get(item.item_id(), null) == item:
		harvestables.erase(item.item_id())


func get_harvestables() -> Array[Harvestable]:
	var result: Array[Harvestable] = []
	for item_id: StringName in harvestables.keys():
		var item := harvestables[item_id] as Harvestable
		if item == null or not is_instance_valid(item):
			harvestables.erase(item_id)
		else:
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
		if item_meta is SeedMeta:
			item = CELL_TOOL_SCENE.instantiate()
			if item != null:
				item.set_script(SEED_SCRIPT)
		elif item_meta is CellToolMeta:
			if item_meta.id == &"basket":
				item = CELL_TOOL_SCENE.instantiate()
				if item != null:
					item.set_script(BASKET_SCRIPT)
			else:
				item = CELL_TOOL_SCENE.instantiate()
				var cell_tool_script: Script = TOOL_SCRIPTS.get(item_meta.id, null)
				if item != null and cell_tool_script != null:
					item.set_script(cell_tool_script)
		else:
			var tool_script: Script = TOOL_SCRIPTS.get(item_meta.id, null)
			item = ITEM_TOOL_SCENE.instantiate()
			if item != null and tool_script != null:
				item.set_script(tool_script)
	elif item_state is PlantState or item_meta is PlantMeta:
		item = PLANT_SCENE.instantiate() as Item
	elif item_state is HarvestableState or item_meta is HarvestableMeta:
		var harvestable_scene := HARVESTABLE_SCENES.get(item_meta.id, HARVESTABLE_SCENE) as PackedScene
		item = harvestable_scene.instantiate() as Item
	else:
		item = ITEM_SCENE.instantiate() as Item
	if item == null:
		return null
	if item.from_state(item_state) != OK:
		item.free()
		return null
	if parent != null:
		parent.add_child(item)
	return item


func create_from_meta(item_meta: ItemMeta, parent: Node = null) -> Item:
	if item_meta == null or item_meta.id == &"":
		return null
	var item_state: ItemState
	if item_meta is ToolMeta:
		item_state = ItemState.new()
		item_state.health = 1
	elif item_meta is PlantMeta:
		item_state = PlantState.new()
		# Plants begin at the first growth stage and advance one stage per watered day.
		item_state.health = 1
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


func to_dict() -> Dictionary:
	return {"unique_count": _unique_count}


func from_dict(data: Dictionary) -> Error:
	if not SerializationUtil.has_valid_int(data, "unique_count") or int(data.unique_count) < 0:
		return ERR_INVALID_DATA
	_unique_count = int(data.unique_count)
	return OK
