class_name ItemMeta
extends Resource

enum ItemType { TOOL, SEED, FOOD, MATERIAL, OBSTACLE, PLANT, FURNITURE }
enum UseKind { NONE, GRID_TOOL, HARVEST_TOOL, SEED, FOOD, DROP }
enum WorldType { NONE, GENERIC, PLANT, HARVESTABLE, PICKUP }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var item_type: ItemType = ItemType.MATERIAL
@export var use_kind: UseKind = UseKind.NONE
@export_range(1, 999, 1) var stack_limit: int = 1
@export_range(0, 999999, 1) var buy_price: int = 0
@export_range(0, 999999, 1) var sell_price: int = 0


func is_tool() -> bool:
	return false


func world_type() -> WorldType:
	return WorldType.GENERIC
