class_name Hoe
extends CellTool


func target_cells(map: BaseMap, player: FarmPlayer) -> Array[Vector2i]:
	var result := super.target_cells(map, player)
	return result.filter(func(cell: Vector2i) -> bool: return map.check_cell(cell, CellState.CellCondition.DIGGABLE))


func _apply_cell(cell: MapCell) -> bool:
	if (
		cell == null
		or not cell.has_flag(CellState.CellFlag.BASE)
		or cell.has_flag(CellState.CellFlag.BLOCKED)
		or not cell.has_flag(CellState.CellFlag.DIGGABLE)
		or cell.has_flag(CellState.CellFlag.DUG)
	):
		return false
	cell.add_flag(CellState.CellFlag.DUG)
	if CalendarManager.check_weather([&"rain", &"storm"]):
		cell.add_flag(CellState.CellFlag.WATERED)
	return true
