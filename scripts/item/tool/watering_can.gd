class_name WateringCan
extends CellTool


func _target_condition() -> CellState.CellCondition:
	return CellState.CellCondition.DUG


func target_cells(map: BaseMap, player: FarmPlayer) -> Array[Vector2i]:
	var result := super.target_cells(map, player)
	return result.filter(
		func(cell: Vector2i) -> bool: return not map.check_cell(cell, CellState.CellCondition.WATERED)
	)


func _apply_cell(cell: MapCell) -> bool:
	if (
		cell == null
		or not cell.has_flag(CellState.CellFlag.DUG)
		or cell.has_flag(CellState.CellFlag.WATERED)
	):
		return false
	cell.add_flag(CellState.CellFlag.WATERED)
	return true
