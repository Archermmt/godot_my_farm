class_name Tool
extends Item

func _init(next_meta: ToolMeta = null) -> void:
	meta = next_meta


func tool_meta() -> ToolMeta:
	return meta as ToolMeta


func max_charge_level() -> int:
	var typed_meta := tool_meta()
	if typed_meta == null:
		return 0
	return typed_meta.max_charge_level()


func targets_cells() -> bool:
	var typed_meta := tool_meta()
	return typed_meta != null and typed_meta.tool_kind in [ToolMeta.ToolKind.HOE, ToolMeta.ToolKind.WATERING_CAN]


func use(
	map: BaseMap,
	target_cells: Array[Vector2i],
	available_stamina: int,
	source_cell: Vector2i = Vector2i(-999999, -999999),
	charge_level: int = 0
) -> ToolOutcome:
	if targets_cells():
		return use_on_cells(map, target_cells, available_stamina)
	return use_on_items(map, target_cells, available_stamina, source_cell, charge_level)


func use_on_cells(map: BaseMap, target_cells: Array[Vector2i], available_stamina: int) -> CellToolOutcome:
	var typed_meta := tool_meta()
	var result := CellToolOutcome.new()
	result.tool_kind = typed_meta.tool_kind if typed_meta != null else ToolMeta.ToolKind.NONE
	var validation_error := _validate_use(map, available_stamina)
	if validation_error != OK:
		result.error = validation_error
		return result
	if typed_meta.tool_kind not in [ToolMeta.ToolKind.HOE, ToolMeta.ToolKind.WATERING_CAN]:
		result.error = ERR_UNAVAILABLE
		return result

	var accepted: Array[MapCell] = []
	var seen: Dictionary[Vector2i, bool] = {}
	for coordinates: Vector2i in target_cells:
		if seen.has(coordinates):
			result.skipped_reasons[coordinates] = &"duplicate"
			continue
		seen[coordinates] = true
		var cell := map.get_cell(coordinates)
		var reason := rejection_reason(cell)
		if reason != &"":
			result.skipped_reasons[coordinates] = reason
			continue
		accepted.append(cell)

	if accepted.is_empty():
		result.error = ERR_UNAVAILABLE
		return result
	var stamina_cost := typed_meta.base_stamina_cost
	if available_stamina < stamina_cost:
		result.error = ERR_CANT_ACQUIRE_RESOURCE
		return result

	var previous_flags: Dictionary[Vector2i, int] = {}
	for cell: MapCell in accepted:
		previous_flags[cell.coordinates] = cell.state_flags()
		var cell_error := cell.use_tool(typed_meta.tool_kind)
		if cell_error != OK:
			for changed_coordinates: Vector2i in previous_flags:
				map.get_cell(changed_coordinates).set_state_flags(previous_flags[changed_coordinates])
			result.error = cell_error
			return result
		result.effect_cells.append(cell.coordinates)

	result.projection_error = map.commit_cell_changes(
		result.effect_cells,
		typed_meta.tool_kind == ToolMeta.ToolKind.HOE
	)
	result.stamina_spent = stamina_cost
	return result


func use_on_items(
	map: BaseMap,
	target_cells: Array[Vector2i],
	available_stamina: int,
	source_cell: Vector2i = Vector2i(-999999, -999999),
	charge_level: int = 0
) -> ItemToolOutcome:
	var typed_meta := tool_meta()
	var result := ItemToolOutcome.new()
	result.tool_kind = typed_meta.tool_kind if typed_meta != null else ToolMeta.ToolKind.NONE
	var validation_error := _validate_use(map, available_stamina)
	if validation_error != OK:
		result.error = validation_error
		return result
	if typed_meta.tool_kind in [ToolMeta.ToolKind.HOE, ToolMeta.ToolKind.WATERING_CAN]:
		result.error = ERR_UNAVAILABLE
		return result

	var accepted: Array[Harvestable] = []
	var seen: Dictionary[StringName, bool] = {}
	for coordinates: Vector2i in target_cells:
		var target := map.harvestable_at(coordinates)
		var reason := harvest_rejection_reason(map, coordinates)
		if target == null or reason != &"":
			result.skipped_reasons[coordinates] = reason
			continue
		if seen.has(target.item_id()):
			result.skipped_reasons[coordinates] = &"duplicate"
			continue
		seen[target.item_id()] = true
		accepted.append(target)

	if accepted.is_empty():
		result.error = ERR_UNAVAILABLE
		return result
	if available_stamina < typed_meta.base_stamina_cost:
		result.error = ERR_CANT_ACQUIRE_RESOURCE
		return result
	var charged_damage := typed_meta.damage_at_charge(clampi(charge_level, 0, max_charge_level()))
	for target: Harvestable in accepted:
		var coordinates: Vector2i = target.state.cell
		if target.apply_tool(typed_meta.tool_kind, charged_damage) != OK:
			result.error = ERR_UNAVAILABLE
			return result
		result.effect_cells.append(coordinates)
		result.hit_item_ids.append(target.item_id())
		if target.is_depleted():
			var depleted_id := target.item_id()
			if target.harvestable_meta().id == &"tree":
				result.tree_fall_directions[depleted_id] = 1 if source_cell.x <= coordinates.x else -1
			result.pickup_ids.append_array(map.resolve_depleted_item(depleted_id))
			result.destroyed_item_ids.append(depleted_id)
	result.stamina_spent = typed_meta.base_stamina_cost
	return result


func rejection_reason(cell: MapCell) -> StringName:
	var typed_meta := tool_meta()
	if cell == null or typed_meta == null:
		return &"missing_cell"
	return cell.tool_rejection_reason(typed_meta.tool_kind)


func harvest_rejection_reason(map: BaseMap, coordinates: Vector2i) -> StringName:
	var typed_meta := tool_meta()
	if map == null or typed_meta == null:
		return &"missing_map"
	var target := map.harvestable_at(coordinates)
	return target.tool_rejection_reason(typed_meta.tool_kind) if target != null else &"missing_target"


func _validate_use(map: BaseMap, available_stamina: int) -> Error:
	var typed_meta := tool_meta()
	if map == null or typed_meta == null or available_stamina < 0:
		return ERR_INVALID_PARAMETER
	if typed_meta.tool_kind == ToolMeta.ToolKind.NONE:
		return ERR_UNAVAILABLE
	return OK
