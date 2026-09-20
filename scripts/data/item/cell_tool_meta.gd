class_name CellToolMeta
extends ToolMeta

func max_charge_level() -> int:
	var legacy_levels: Variant = get("charge_levels")
	if legacy_levels is Array and not legacy_levels.is_empty():
		return legacy_levels.size() - 1
	return maxi(0, levels.size() - 1)

func level_area(level: int) -> Vector2i:
	var legacy_levels: Variant = get("charge_levels")
	if legacy_levels is Array and not legacy_levels.is_empty():
		return legacy_levels[clampi(level, 0, legacy_levels.size() - 1)]
	if levels.is_empty():
		return Vector2i.ONE
	var value := levels[clampi(level, 0, levels.size() - 1)]
	if value is CellToolLevel:
		return value.range
	return Vector2i.ONE
