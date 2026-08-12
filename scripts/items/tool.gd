class_name Tool
extends RefCounted

var meta: ToolMeta = null


func _init(tool_meta: ToolMeta = null) -> void:
	meta = tool_meta


func use(map: BaseMap, target_cells: Array[Vector2i], available_stamina: int) -> ToolUseResult:
	var result := ToolUseResult.new()
	result.tool_kind = meta.tool_kind if meta != null else ToolMeta.ToolKind.NONE
	if map == null or meta == null or available_stamina < 0:
		result.error = ERR_INVALID_PARAMETER
		return result
	if meta.tool_kind not in [ToolMeta.ToolKind.HOE, ToolMeta.ToolKind.WATERING_CAN]:
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
	var stamina_cost := meta.base_stamina_cost
	if available_stamina < stamina_cost:
		result.error = ERR_CANT_ACQUIRE_RESOURCE
		return result

	var previous_flags: Dictionary[Vector2i, int] = {}
	for cell: MapCell in accepted:
		previous_flags[cell.coordinates] = cell.flags()
		var cell_error := cell.use_tool(meta.tool_kind)
		if cell_error != OK:
			for changed_coordinates: Vector2i in previous_flags:
				map.get_cell(changed_coordinates).set_flags(previous_flags[changed_coordinates])
			result.error = cell_error
			return result
		result.effect_cells.append(cell.coordinates)

	result.projection_error = map.commit_cell_changes(result.effect_cells)
	result.stamina_spent = stamina_cost
	return result


func rejection_reason(cell: MapCell) -> StringName:
	if cell == null or meta == null:
		return &"missing_cell"
	return cell.tool_rejection_reason(meta.tool_kind)
