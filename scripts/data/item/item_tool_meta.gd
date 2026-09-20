class_name ItemToolMeta
extends ToolMeta

func max_charge_level() -> int:
	return maxi(0, levels.size() - 1)

func level_damage(level: int) -> int:
	if levels.is_empty():
		return 1
	var value := levels[clampi(level, 0, levels.size() - 1)]
	if value is ItemToolLevel:
		return (value as ItemToolLevel).damage
	if value is ToolLevel and value.get("damage") != null:
		return maxi(1, int(value.get("damage")))
	return 1

func level_scale(level: int) -> float:
	if levels.is_empty():
		return 1.0
	var value := levels[clampi(level, 0, levels.size() - 1)]
	if value is ItemToolLevel:
		return (value as ItemToolLevel).scale
	return 1.0
