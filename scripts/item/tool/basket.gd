class_name Basket
extends CellTool


func _target_condition() -> CellState.CellCondition:
	return CellState.CellCondition.WALKABLE


func _preview_cell_usable(map: BaseMap, cell: Vector2i, usable_count: int) -> bool:
	if not super._preview_cell_usable(map, cell, usable_count):
		return false
	var map_cell := map.get_cell(cell)
	if map_cell == null:
		return false
	for candidate_id: StringName in map_cell.state.item_ids:
		var plant := map.get_item(candidate_id) as Plant
		if plant != null and plant.is_mature():
			return true
	return false


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
			plant.state.health = 0
			plant.add_flag(ItemMeta.ItemFlag.DESTROYED)
			var cell_state := map_cell.state
			cell_state.usable = true
			cell_state.invalid = false
			result.cells[cell] = cell_state
			result.items[candidate_id] = plant.state
			for pickup_id: StringName in map.resolve_depleted_item(candidate_id, player):
				var pickup := map.get_item(pickup_id)
				if pickup != null and pickup.state != null:
					result.items[pickup_id] = pickup.state
	return result
