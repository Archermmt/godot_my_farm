class_name ToolMeta
extends ItemMeta

enum ToolKind { NONE, HOE, WATERING_CAN, SICKLE, BASKET, PICKAXE, AXE }

@export var tool_kind: ToolKind = ToolKind.NONE
@export var event_id: StringName = &"tool_use"
@export var is_cell_tool: bool = false
@export_range(0, 999, 1) var base_energy_cost: int = 0
@export var levels: Array[ToolLevel] = [ToolLevel.new()]


func charges_damage() -> bool:
	return tool_kind in [ToolKind.PICKAXE, ToolKind.AXE]


func max_charge_level() -> int:
	return maxi(0, levels.size() - 1)


func level_area(level: int) -> Vector2i:
	if levels.is_empty():
		return Vector2i.ONE
	var configured := levels[clampi(level, 0, levels.size() - 1)]
	return Vector2i(maxi(1, configured.effect_range.x), maxi(1, configured.effect_range.y))


func level_damage(level: int) -> int:
	if levels.is_empty():
		return 1
	return levels[clampi(level, 0, levels.size() - 1)].damage


func level_energy_cost(level: int) -> int:
	return base_energy_cost * (clampi(level, 0, max_charge_level()) + 1)
