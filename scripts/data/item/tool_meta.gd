class_name ToolMeta
extends ItemMeta

enum ToolKind { NONE, HOE, WATERING_CAN, SICKLE, BASKET, PICKAXE, AXE }

@export var tool_kind: ToolKind = ToolKind.NONE
@export var event_id: StringName = &"tool_use"
@export var levels: Array[ToolLevel] = []


func charges_damage() -> bool:
	return tool_kind in [ToolKind.PICKAXE, ToolKind.AXE]


func max_charge_level() -> int:
	return maxi(0, levels.size() - 1)


func level_area(_level: int) -> Vector2i:
	return Vector2i.ONE


func level_damage(level: int) -> int:
	if not levels.is_empty() and levels[0] is ItemToolLevel:
		return (levels[clampi(level, 0, levels.size() - 1)] as ItemToolLevel).damage
	return 1


func level_energy_cost(level: int) -> int:
	if levels.is_empty():
		return 1
	return levels[clampi(level, 0, max_charge_level())].energy_cost
