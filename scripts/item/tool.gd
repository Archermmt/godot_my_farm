class_name Tool
extends Item


func _init(item_state: ItemState = null) -> void:
	super._init(item_state)


func max_charge_level() -> int:
	var typed_meta := meta as ToolMeta
	if typed_meta == null:
		return 0
	return typed_meta.max_charge_level()


func use(
	map: BaseMap,
	target_cells: Array[Vector2i],
	available_energy: int,
	charge_level: int = 0
) -> ApplyResult:
	var typed_meta := meta as ToolMeta
	var result := ApplyResult.new()
	if map == null or typed_meta == null or typed_meta.tool_kind == ToolMeta.ToolKind.NONE or available_energy < 0:
		return result
	var normalized_level := clampi(charge_level, 0, max_charge_level())
	if available_energy < typed_meta.level_energy_cost(normalized_level):
		return result
	var applied_result: ApplyResult
	if typed_meta.is_cell_tool:
		applied_result = use_on_cells(map, target_cells)
	else:
		applied_result = use_on_items(map, target_cells, normalized_level)
	if applied_result.succeeded():
		var positions: Array[Vector2] = []
		for cell: Vector2i in applied_result.cells:
			positions.append(map.cell_to_world(cell))
		EffectManager.play_effect(typed_meta.event_id, positions)
		AudioManager.play_audio(typed_meta.event_id)
	return applied_result


func use_on_cells(map: BaseMap, target_cells: Array[Vector2i]) -> ApplyResult:
	var typed_meta := meta as ToolMeta
	var result := ApplyResult.new()
	var seen: Dictionary[Vector2i, bool] = {}
	for coordinates: Vector2i in target_cells:
		if seen.has(coordinates):
			continue
		seen[coordinates] = true
		var cell := map.get_cell(coordinates)
		if cell == null:
			continue
		if not cell.apply_tool(typed_meta.tool_kind):
			continue
		result.cells.append(coordinates)

	if result.cells.is_empty():
		return result
	map.rebuild_layers()
	return result


func use_on_items(
	map: BaseMap, target_cells: Array[Vector2i], charge_level: int = 0
) -> ApplyResult:
	var typed_meta := meta as ToolMeta
	var result := ApplyResult.new()
	var charged_damage := typed_meta.level_damage(charge_level)
	var seen: Dictionary[StringName, bool] = {}
	for coordinates: Vector2i in target_cells:
		var target := map.harvestable_at(coordinates)
		if target == null:
			continue
		var target_id := target.item_id()
		if seen.has(target_id):
			continue
		seen[target_id] = true
		if target.apply_tool(typed_meta.tool_kind, charged_damage) != ItemMeta.ItemFlag.AVAILABLE:
			continue
		result.cells.append(coordinates)
		target.state.add_flag(ItemMeta.ItemFlag.DESTROYED if target.is_depleted() else ItemMeta.ItemFlag.HURT)
		result.items[target_id] = target.state
		if target.is_depleted():
			var pickup_ids := map.resolve_depleted_item(target_id)
			for pickup_id: StringName in pickup_ids:
				var pickup := map.get_item(pickup_id)
				if pickup != null and pickup.state != null:
					pickup.state.add_flag(ItemMeta.ItemFlag.DROPPED)
					result.items[pickup_id] = pickup.state
	return result
