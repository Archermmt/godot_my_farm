class_name ItemDefinition
extends Resource

enum ItemType { TOOL, SEED, FOOD, MATERIAL, OBSTACLE, PLANT, FURNITURE }
enum UseKind { NONE, GRID_TOOL, HARVEST_TOOL, SEED, FOOD, DROP }
enum ToolKind { NONE, HOE, WATERING_CAN, SICKLE, BASKET, PICKAXE, AXE }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var item_type: ItemType = ItemType.MATERIAL
@export var use_kind: UseKind = UseKind.NONE
@export var tool_kind: ToolKind = ToolKind.NONE
@export_range(1, 999, 1) var stack_limit: int = 1
@export_range(0, 999999, 1) var buy_price: int = 0
@export_range(0, 999999, 1) var sell_price: int = 0
@export_range(0, 999, 1) var base_stamina_cost: int = 0
@export var related_crop_id: StringName = &""
@export var animation_tags: Array[StringName] = []


func is_tool() -> bool:
	return item_type == ItemType.TOOL
