class_name Seed
extends Item

var plant_meta: PlantMeta = null


func _init(next_meta: SeedMeta = null, catalog: DataCatalogService = null) -> void:
	meta = next_meta
	if next_meta != null and catalog != null and next_meta.plant_id != &"":
		plant_meta = catalog.get_plant(next_meta.plant_id)


static func perform(
	meta: SeedMeta,
	catalog_service: DataCatalogService,
	map: BaseMap,
	target_cells: Array[Vector2i],
	planted_on_day: int,
	available_count: int
) -> SeedOutcome:
	var seed := Seed.new(meta, catalog_service)
	var result := seed.use(map, target_cells, planted_on_day, available_count)
	seed.free()
	return result


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
