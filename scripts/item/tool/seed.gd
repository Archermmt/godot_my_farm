class_name Seed
extends CellTool


func _target_condition() -> CellState.CellCondition:
	return CellState.CellCondition.PLANTABLE


func _preview_cell_usable(map: BaseMap, cell: Vector2i, usable_count: int) -> bool:
	if not super._preview_cell_usable(map, cell, usable_count):
		return false
	var seed_meta := meta as SeedMeta
	var available := GameManager.player.backpack.count_item(&"itembar", seed_meta.id) if seed_meta != null and GameManager.player != null and GameManager.player.backpack != null else 0
	return usable_count < available


func _use_impl() -> ApplyResult:
	var map := MapManager.current_map()
	var player := GameManager.player
	var result := ApplyResult.new()
	if map == null or player == null or not meta is SeedMeta:
		return result
	var seed_meta := meta as SeedMeta
	var available := player.backpack.count_item(&"itembar", seed_meta.id) if player.backpack != null else 0
	for coordinates: Vector2i in target_cells(map, player):
		if result.usable_cell_count() >= available:
			break
		var plant := ItemManager.create_from_id(seed_meta.plant_id)
		if plant == null or map.add_item(plant, map.cell_to_world(coordinates)) != OK:
			if plant != null:
				plant.free()
			continue
		plant.add_flag(ItemMeta.ItemFlag.PLANTED)
		var cell_state := map.get_cell(coordinates).state if map.get_cell(coordinates) != null else CellState.new()
		cell_state.usable = true
		cell_state.invalid = false
		result.cells[coordinates] = cell_state
		result.items[plant.item_id()] = plant.state
	return result
