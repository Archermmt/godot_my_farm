class_name Seed
extends Item

var plant_meta: PlantMeta = null


func _init(item_state: ItemState = null) -> void:
	super._init(item_state)
	if meta is SeedMeta and (meta as SeedMeta).plant_id != &"":
		plant_meta = DataCatalog.get_plant((meta as SeedMeta).plant_id)


func use(map: BaseMap, target_cells: Array[Vector2i], planted_on_day: int, available_count: int) -> SeedOutcome:
	var result := SeedOutcome.new()
	result.seed_item_id = meta.id if meta != null else &""
	if map == null or not meta is SeedMeta or plant_meta == null or available_count <= 0:
		result.error = ERR_INVALID_PARAMETER
		return result
	if target_cells.is_empty():
		result.error = ERR_UNAVAILABLE
		return result
	if target_cells.size() > available_count:
		target_cells = target_cells.slice(0, available_count)
	var created_instance_ids: Array[StringName] = []
	for cell: Vector2i in target_cells:
		if not map.check_cell(cell, BaseMap.CellCondition.PLANTABLE):
			result.error = ERR_UNAVAILABLE
			return result
	for cell: Vector2i in target_cells:
		var state := PlantState.new()
		state.instance_id = map.create_item_instance_id(plant_meta.id)
		state.meta_id = plant_meta.id
		state.planted_on_day = maxi(1, planted_on_day)
		var add_error := map.add_item_state(state, cell)
		if add_error != OK:
			for instance_id: StringName in created_instance_ids:
				map.remove_item(instance_id)
			result.effect_cells.clear()
			result.error = add_error
			return result
		result.effect_cells.append(cell)
		created_instance_ids.append(state.instance_id)
	return result
