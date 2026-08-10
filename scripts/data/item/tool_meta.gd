class_name ToolMeta
extends ItemMeta

enum ToolKind { NONE, HOE, WATERING_CAN, SICKLE, BASKET, PICKAXE, AXE }

@export var tool_kind: ToolKind = ToolKind.NONE
@export_range(0, 999, 1) var base_stamina_cost: int = 0


func _init() -> void:
	item_type = ItemType.TOOL


func is_tool() -> bool:
	return true
