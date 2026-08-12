class_name SeedItem
extends RefCounted

var seed_meta: ItemMeta = null
var catalog: DataCatalogService = null

func _init(next_meta: ItemMeta = null, next_catalog: DataCatalogService = null) -> void:
	seed_meta = next_meta
	catalog = next_catalog

func use(map: BaseMap, target_cells: Array[Vector2i], planted_on_day: int, available_count: int) -> SeedUseResult:
	var result := SeedUseResult.new()
	result.seed_item_id = seed_meta.id if seed_meta != null else &""
	if map == null or seed_meta == null or seed_meta.use_kind != ItemMeta.UseKind.SEED or catalog == null or available_count <= 0:
		result.error = ERR_INVALID_PARAMETER
		return result
	if target_cells.is_empty():
		result.error = ERR_UNAVAILABLE
		return result
	if target_cells.size() > available_count:
		target_cells = target_cells.slice(0, available_count)
	var plant_meta: PlantMeta = null
	for item_id: StringName in catalog.item_ids():
		var candidate := catalog.get_item(item_id)
		if candidate is PlantMeta and (candidate as PlantMeta).seed_item_id == seed_meta.id:
			plant_meta = candidate as PlantMeta
			break
	if plant_meta == null:
		result.error = ERR_DOES_NOT_EXIST
		return result
	for cell: Vector2i in target_cells:
		if map.get_cell(cell) == null or not map.get_cell(cell).can_plant():
			result.error = ERR_UNAVAILABLE
			return result
	for cell: Vector2i in target_cells:
		var state := PlantState.new()
		state.instance_id = map.create_item_instance_id(plant_meta.id)
		state.meta_id = plant_meta.id
		state.cell = cell
		state.planted_on_day = maxi(1, planted_on_day)
		var add_error := map.add_item_state(state)
		if add_error != OK:
			for instance_id: StringName in result.instance_ids:
				map.remove_item(instance_id)
			result.effect_cells.clear()
			result.instance_ids.clear()
			result.error = add_error
			return result
		result.effect_cells.append(cell)
		result.instance_ids.append(state.instance_id)
	return result
