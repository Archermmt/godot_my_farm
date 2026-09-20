class_name Basket
extends CellTool


func _target_condition() -> CellState.CellCondition:
	return CellState.CellCondition.WALKABLE


func target_cells(map: BaseMap, player: FarmPlayer) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in super.target_cells(map, player):
		var map_cell := map.get_cell(cell)
		if map_cell == null:
			continue
		for candidate_id: StringName in map_cell.state.item_ids:
			var plant := map.get_item(candidate_id) as Plant
			if plant != null and plant.is_mature():
				result.append(cell)
				break
	return result


func _use_impl() -> ApplyResult:
	var map := MapManager.current_map()
	var player := GameManager.player
	var result := ApplyResult.new()
	if map == null or player == null:
		return result
	for cell in target_cells(map, player):
		var map_cell := map.get_cell(cell)
		if map_cell == null:
			continue
		for candidate_id: StringName in map_cell.state.item_ids.duplicate():
			var plant := map.get_item(candidate_id) as Plant
			if plant == null or not plant.is_mature():
				continue
			plant.apply_tool(ToolMeta.ToolKind.BASKET, 1)
			result.cells[cell] = map_cell.state
			result.items[candidate_id] = plant.state
			map.resolve_depleted_item(candidate_id)
	return result
