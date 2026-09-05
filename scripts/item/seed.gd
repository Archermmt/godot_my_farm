class_name Seed
extends Item

var plant_id: StringName = &""


func _init(item_state: ItemState = null) -> void:
	super._init(item_state)
	if meta is SeedMeta:
		plant_id = (meta as SeedMeta).plant_id


func use(map: BaseMap, target_cells: Array[Vector2i], available_count: int) -> ApplyResult:
	var result := ApplyResult.new()
	if map == null or not meta is SeedMeta or plant_id == &"" or available_count <= 0:
		return result
	if target_cells.is_empty():
		return result
	var created_unique_ids: Array[StringName] = []
	var planted_count := 0
	for cell: Vector2i in target_cells:
		if planted_count >= available_count:
			break
		if not map.check_cell(cell, CellState.CellCondition.PLANTABLE):
			continue
		var plant := ItemManager.create_from_id(plant_id)
		if plant == null or not plant.state is PlantState:
			continue
		var plant_state := plant.state as PlantState
		plant_state.add_flag(ItemMeta.ItemFlag.PLANTED)
		var add_error := map.add_item(plant, map.cell_to_world(cell))
		if add_error != OK:
			plant.free()
			for unique_id: StringName in created_unique_ids:
				map.remove_item(unique_id)
			result.cells.clear()
			result.items.clear()
			return result
		result.cells.append(cell)
		result.items[plant_state.unique_id] = plant_state
		created_unique_ids.append(plant_state.unique_id)
		planted_count += 1
	return result
