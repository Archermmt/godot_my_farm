class_name ItemsGenerator
extends Node

@export_category("Candidates")
@export var candidates: Dictionary[StringName, ItemsGeneratorCandidate] = {}

@export_category("Generation Control")
@export_range(1, 10000, 1) var max_attempts_per_item: int = 64
@export_range(0, 16, 1) var safe_radius: int = 2
@export var seed_salt: int = 0
@export var regenerate_daily: bool = false


func generate(
	map: BaseMap, map_size: Vector2i, world_seed: int, generation_epoch: int, trace_delay_seconds: float = 0.0
) -> Dictionary:
	var summary := {"requested": 0, "spawned": 0, "attempts": 0, "skipped": 0}
	if map == null or map_size.x <= 0 or map_size.y <= 0 or generation_epoch < 0:
		summary["error"] = ERR_INVALID_PARAMETER
		return summary
	var validation_result := validation_error()
	if validation_result != OK:
		summary["error"] = validation_result
		return summary
	var rng := RandomNumberGenerator.new()
	rng.seed = _derived_seed(world_seed, map.map_id, generation_epoch, seed_salt)
	var safe_cells := _safe_cells(map, safe_radius)
	var occupied: Array[Vector2i] = []
	for coordinates: Vector2i in map.cells:
		if map.cells[coordinates].has_occupant():
			occupied.append(coordinates)

	for meta_id: StringName in candidates:
		var candidate := candidates[meta_id]
		if candidate == null or meta_id == &"":
			continue
		var item_meta := DataCatalog.get_item(meta_id)
		if not _supports_meta(item_meta):
			summary["skipped"] = int(summary["skipped"]) + 1
			continue
		var available := _available_cells(map, map_size, safe_cells, candidate)
		var target_count: int
		if candidate.max_count > 0:
			target_count = rng.randi_range(candidate.min_count, candidate.max_count)
		else:
			target_count = maxi(candidate.min_count, floori(available.size() * candidate.density))
		summary["requested"] = int(summary["requested"]) + target_count
		var spawned_for_candidate := 0
		var attempts := 0
		while (
			spawned_for_candidate < target_count
			and attempts < target_count * max_attempts_per_item
			and not available.is_empty()
		):
			attempts += 1
			summary["attempts"] = int(summary["attempts"]) + 1
			var available_index := rng.randi_range(0, available.size() - 1)
			var coordinates: Vector2i = available[available_index]
			available.remove_at(available_index)
			if not _far_enough(coordinates, occupied, candidate.min_distance):
				continue
			var state := _create_item_state(item_meta)
			if state == null:
				continue
			state.instance_id = StringName(
				"generated_%s_%d_%s_%03d" % [map.map_id, generation_epoch, meta_id, spawned_for_candidate]
			)
			state.meta_id = meta_id
			state.random_seed = rng.randi()
			state.flags = [&"generated"]
			if map.add_item_state(state, coordinates, trace_delay_seconds) != OK:
				continue
			occupied.append(coordinates)
			spawned_for_candidate += 1
			summary["spawned"] = int(summary["spawned"]) + 1
		summary["skipped"] = int(summary["skipped"]) + target_count - spawned_for_candidate
	summary["error"] = OK
	return summary


func validation_error() -> Error:
	if max_attempts_per_item <= 0 or safe_radius < 0 or candidates.is_empty():
		return ERR_INVALID_DATA
	for meta_id: StringName in candidates:
		var candidate := candidates[meta_id]
		if candidate == null or meta_id == &"" or candidate.required_flags.is_empty():
			return ERR_INVALID_DATA
		if (
			candidate.min_count < 0
			or candidate.max_count < 0
			or (candidate.max_count > 0 and candidate.max_count < candidate.min_count)
		):
			return ERR_INVALID_DATA
		if candidate.max_count == 0 and candidate.density <= 0.0:
			return ERR_INVALID_DATA
		if candidate.density < 0.0 or candidate.density > 1.0 or candidate.min_distance < 0.0:
			return ERR_INVALID_DATA
		if not DataCatalog.has_item(meta_id) or not _supports_meta(DataCatalog.get_item(meta_id)):
			return ERR_INVALID_DATA
	return OK


static func _supports_meta(item_meta: ItemMeta) -> bool:
	return item_meta is HarvestableMeta or (item_meta != null and not item_meta is ToolMeta and item_meta.can_pickup)


static func _create_item_state(item_meta: ItemMeta) -> ItemState:
	if item_meta is PlantMeta:
		var plant_state := PlantState.new()
		plant_state.health = (item_meta as PlantMeta).health
		return plant_state
	if item_meta is HarvestableMeta:
		var harvestable_state := HarvestableState.new()
		harvestable_state.health = (item_meta as HarvestableMeta).health
		return harvestable_state
	if item_meta != null and not item_meta is ToolMeta and item_meta.can_pickup:
		return ItemState.new()
	return null


func _available_cells(
	map: BaseMap, map_size: Vector2i, safe_cells: Dictionary[Vector2i, bool], candidate: ItemsGeneratorCandidate
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var map_bounds := Rect2i(Vector2i.ZERO, map_size)
	for coordinates: Vector2i in map.cells:
		if not map_bounds.has_point(coordinates):
			continue
		var cell := map.get_cell(coordinates)
		if cell == null or cell.has_occupant() or safe_cells.has(coordinates):
			continue
		if not _has_all_flags(cell, candidate.required_flags):
			continue
		result.append(coordinates)
	result.sort_custom(
		func(left: Vector2i, right: Vector2i) -> bool:
			return left.y < right.y or (left.y == right.y and left.x < right.x)
	)
	return result


static func _has_all_flags(cell: MapCell, flags: Array[CellState.CellFlag]) -> bool:
	for flag: CellState.CellFlag in flags:
		if not cell.has_static_flag(flag):
			return false
	return true


static func _safe_cells(map: BaseMap, radius: int) -> Dictionary[Vector2i, bool]:
	var result: Dictionary[Vector2i, bool] = {}
	for parent_name: StringName in [&"SpawnPoints", &"Ports"]:
		var parent := map.get_node_or_null(String(parent_name))
		if parent == null:
			continue
		for child: Node in parent.get_children():
			if child is Node2D:
				var center := map.world_to_cell((child as Node2D).global_position)
				for y: int in range(center.y - radius, center.y + radius + 1):
					for x: int in range(center.x - radius, center.x + radius + 1):
						result[Vector2i(x, y)] = true
	return result


static func _far_enough(cell: Vector2i, occupied: Array[Vector2i], min_distance: float) -> bool:
	if min_distance <= 0.0:
		return true
	for other: Vector2i in occupied:
		if Vector2(cell).distance_to(Vector2(other)) < min_distance:
			return false
	return true


static func _derived_seed(world_seed: int, map_id: StringName, epoch: int, salt: int) -> int:
	var result := world_seed ^ salt ^ (epoch * 1103515245)
	for byte: int in String(map_id).to_utf8_buffer():
		result = int((result * 16777619) ^ byte)
	return result
