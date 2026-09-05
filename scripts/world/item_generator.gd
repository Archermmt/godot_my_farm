class_name ItemGenerator
extends Node

@export_category("Candidates")
@export var candidates: Array[ItemGeneratorCandidate] = []

@export_category("Generation Control")
@export_range(1, 10000, 1) var max_attempts_per_item: int = 64
@export var seed_salt: int = 0
@export var regenerate_daily: bool = false


func generate(map: BaseMap) -> Error:
	var map_size := map.get_map_size() if map != null else Vector2i.ZERO
	var generation_epoch := map.generation_epoch() if map != null else -1
	if map == null or map_size.x <= 0 or map_size.y <= 0 or generation_epoch < 0:
		return ERR_INVALID_PARAMETER
	var validation_result := validation_error()
	if validation_result != OK:
		return validation_result
	var trace_delay_seconds := float(DataCatalog.config.player_trace_delay.get(&"generate", 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = _derived_seed(DataCatalog.config.default_world_seed, map.map_id, generation_epoch, seed_salt)
	var occupied: Array[Vector2i] = []
	for coordinates: Vector2i in map.cells:
		if map.cells[coordinates].has_occupant():
			occupied.append(coordinates)

	for candidate: ItemGeneratorCandidate in candidates:
		if candidate == null:
			continue
		var available := _available_cells(map, map_size, candidate)
		var target_count: int
		if candidate.max_count > 0:
			target_count = rng.randi_range(candidate.min_count, candidate.max_count)
		else:
			target_count = maxi(candidate.min_count, floori(available.size() * candidate.density))
		var spawned_for_candidate := 0
		var attempts := 0
		while (
			spawned_for_candidate < target_count
			and attempts < target_count * max_attempts_per_item
			and not available.is_empty()
		):
			attempts += 1
			var available_index := rng.randi_range(0, available.size() - 1)
			var coordinates: Vector2i = available[available_index]
			available.remove_at(available_index)
			if not _far_enough(coordinates, occupied, candidate.min_distance):
				continue
			var meta_id: StringName = candidate.item_ids[rng.randi_range(0, candidate.item_ids.size() - 1)]
			var item := ItemManager.create_from_id(meta_id)
			if item == null:
				continue
			item.state.add_flag(ItemMeta.ItemFlag.GENERATED)
			var tile_size := Vector2(map.get_tile_size())
			var item_position := map.cell_to_world(coordinates, false)
			if map.add_item(item, item_position) != OK:
				item.free()
				continue
			item.set_trace_delay(trace_delay_seconds)
			occupied.append(coordinates)
			spawned_for_candidate += 1
	return OK


func validation_error() -> Error:
	if max_attempts_per_item <= 0 or candidates.is_empty():
		return ERR_INVALID_DATA
	for candidate: ItemGeneratorCandidate in candidates:
		if candidate == null or candidate.item_ids.is_empty() or candidate.required_flags.is_empty():
			return ERR_INVALID_DATA
		for meta_id: StringName in candidate.item_ids:
			if meta_id == &"" or not DataCatalog.has_item(meta_id) or not _supports_meta(DataCatalog.get_item(meta_id)):
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
	return OK


static func _supports_meta(item_meta: ItemMeta) -> bool:
	return item_meta is HarvestableMeta or (item_meta != null and not item_meta is ToolMeta and item_meta.can_pickup)


func _available_cells(map: BaseMap, map_size: Vector2i, candidate: ItemGeneratorCandidate) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var map_bounds := Rect2i(Vector2i.ZERO, map_size)
	for coordinates: Vector2i in map.cells:
		if not map_bounds.has_point(coordinates):
			continue
		var cell := map.get_cell(coordinates)
		if cell == null or cell.has_occupant():
			continue
		if not cell.has_all_flags(candidate.required_flags):
			continue
		result.append(coordinates)
	result.sort_custom(
		func(left: Vector2i, right: Vector2i) -> bool:
			return left.y < right.y or (left.y == right.y and left.x < right.x)
	)
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
