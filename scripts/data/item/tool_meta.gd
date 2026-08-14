class_name ToolMeta
extends ItemMeta

enum ToolKind { NONE, HOE, WATERING_CAN, SICKLE, BASKET, PICKAXE, AXE }

@export var tool_kind: ToolKind = ToolKind.NONE
@export_range(0, 999, 1) var base_stamina_cost: int = 0
@export_range(1, 999, 1) var damage: int = 1
@export var charge_levels: Array[Vector2i] = [Vector2i.ONE, Vector2i(3, 1), Vector2i(3, 3), Vector2i(9, 3), Vector2i(9, 9)]


func _init() -> void:
	item_type = ItemType.TOOL


func is_tool() -> bool:
	return true
