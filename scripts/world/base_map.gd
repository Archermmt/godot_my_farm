class_name BaseMap
extends Node2D

enum CellCondition { HAS_OCCUPANT, PLANTABLE, DROPABLE }

@export var map_id: StringName = &"farm"
@export var cell_flags: Dictionary[TileMapLayer, CellState.CellFlag] = {}
@export var items_host: Node2D = null
@export var harvestables_host: Node2D = null
@export var plants_host: Node2D = null

var cells: Dictionary[Vector2i, MapCell] = {}
var items: Dictionary[StringName, Item] = {}
var interaction_revision: int = 0
var _map_state: MapState = null
var _dug_layer: TileMapLayer = null
var _watered_layer: TileMapLayer = null
var _world_seed: int = 0
var _generated_trace_delay: float = 0.0
var drop_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var last_generation_summary: Dictionary = {}
@onready var spawn_points: Node2D = $SpawnPoints
@onready var items_generator: ItemsGenerator = get_node_or_null("ItemsGenerator") as ItemsGenerator


func _ready() -> void:
	if not EventBus.day_advanced.is_connected(_on_day_advanced):
		EventBus.day_advanced.connect(_on_day_advanced)
	if not EventBus.weather_changed.is_connected(_on_weather_changed):
		EventBus.weather_changed.connect(_on_weather_changed)
	_build_cells()


func pickup_items_in_radius(center: Vector2, radius: float) -> Array[Item]:
	var result: Array[Item] = []
	if radius <= 0.0:
		return result
	for item: Item in items.values():
		if item == null:
			continue
		if item is Harvestable or item.meta == null or not item.meta.can_pickup:
			continue
		if item.global_position.distance_to(center) <= radius:
			result.append(item)
	result.sort_custom(
		func(left: Item, right: Item) -> bool:
			var left_distance := left.global_position.distance_squared_to(center)
			var right_distance := right.global_position.distance_squared_to(center)
			if not is_equal_approx(left_distance, right_distance):
				return left_distance < right_distance
			return String(left.item_id()) < String(right.item_id())
	)
	return result


func configure_state(
	map_state: MapState, world_seed: int = 0, run_generation: bool = false, generated_trace_delay: float = 0.0
) -> Error:
	if map_state == null or map_state.map_id != map_id:
		return ERR_INVALID_PARAMETER
	if cells.is_empty():
		return ERR_UNCONFIGURED
	for coordinates: Vector2i in map_state.cells:
		var saved_state: CellState = map_state.cells[coordinates]
		if not cells.has(coordinates) or saved_state == null or saved_state.cell != coordinates:
			return ERR_INVALID_DATA
	for coordinates: Vector2i in cells:
		var state := map_state.cells.get(coordinates, null) as CellState
		if state == null:
			state = CellState.new()
			state.cell = coordinates
			map_state.cells[coordinates] = state
	var seen_item_ids: Dictionary[StringName, bool] = {}
	for coordinates: Vector2i in map_state.cells:
		var state: CellState = map_state.cells[coordinates]
		for item_id: StringName in state.item_ids:
			var item_state := map_state.items.get(item_id, null) as ItemState
			if (
				item_state == null
				or item_state.instance_id != item_id
				or item_state.cell != coordinates
				or seen_item_ids.has(item_id)
			):
				return ERR_INVALID_DATA
			seen_item_ids[item_id] = true
	if seen_item_ids.size() != map_state.items.size():
		return ERR_INVALID_DATA
	var restored_items: Array[Item] = []
	for item_id: StringName in map_state.items:
		var item_state: ItemState = map_state.items[item_id]
		if item_state == null or item_state.instance_id != item_id or not DataCatalog.has_item(item_state.meta_id):
			return ERR_INVALID_DATA
		var item_meta := DataCatalog.get_item(item_state.meta_id)
		if not _state_matches_meta(item_state, item_meta):
			return ERR_INVALID_DATA
		if _item_host_for_meta(item_meta) == null:
			return ERR_UNCONFIGURED
		if not cells.has(item_state.cell):
			return ERR_INVALID_DATA
		var item := _create_item(item_state)
		if item == null:
			return ERR_INVALID_DATA
		restored_items.append(item)
	_clear_items()
	for coordinates: Vector2i in cells:
		var bind_error := cells[coordinates].bind_state(map_state.cells[coordinates])
		if bind_error != OK:
			return bind_error
	_map_state = map_state
	_world_seed = world_seed
	_generated_trace_delay = maxf(generated_trace_delay, 0.0)
	for item: Item in restored_items:
		var add_error := add_item(item)
		if add_error != OK:
			_clear_items()
			return add_error
	last_generation_summary = {}
	if run_generation and not map_state.generator_initialized:
		if items_generator == null:
			map_state.generator_initialized = true
		else:
			last_generation_summary = items_generator.generate(
				self, get_map_size(), world_seed, map_state.generation_epoch, _generated_trace_delay
			)
			var generation_error: Error = int(last_generation_summary.get("error", ERR_INVALID_DATA))
			if generation_error != OK:
				return generation_error
			map_state.generator_initialized = true
	interaction_revision += 1
	var projection_error := rebuild_cell_state_layers()
	if projection_error == OK:
		_apply_current_weather()
	return projection_error


func validate_alignment() -> Error:
	var container := tilemap_container()
	if (
		container == null
		or container.position != Vector2.ZERO
		or container.rotation != 0.0
		or container.scale != Vector2.ONE
	):
		return ERR_UNCONFIGURED
	var layers := managed_layers()
	if layers.is_empty() or coordinate_layer() == null:
		return ERR_UNCONFIGURED
	var tile_size := get_tile_size()
	var map_size := get_map_size()
	if tile_size.x <= 0 or tile_size.y <= 0 or map_size.x <= 0 or map_size.y <= 0:
		return ERR_INVALID_DATA
	for layer: TileMapLayer in layers:
		if layer.tile_set == null or layer.tile_set.tile_size != tile_size:
			return ERR_UNCONFIGURED
		if layer.position != Vector2.ZERO or layer.rotation != 0.0 or layer.scale != Vector2.ONE:
			return ERR_INVALID_DATA
	if cell_flags.is_empty():
		return ERR_UNCONFIGURED
	var base_layer_count := 0
	for layer: TileMapLayer in cell_flags:
		if layer == null or layer not in layers or int(cell_flags[layer]) == 0:
			return ERR_INVALID_DATA
		if cell_flags[layer] == CellState.CellFlag.BASE:
			base_layer_count += 1
		for coordinates: Vector2i in layer.get_used_cells():
			if not contains_cell(coordinates):
				return ERR_INVALID_DATA
	if base_layer_count != 1:
		return ERR_INVALID_DATA
	var configured_hosts: Dictionary[Node2D, bool] = {}
	for host: Node2D in [items_host, harvestables_host, plants_host]:
		if host == null:
			continue
		if not is_ancestor_of(host) or configured_hosts.has(host):
			return ERR_INVALID_DATA
		configured_hosts[host] = true
	return OK


func managed_layers() -> Array[TileMapLayer]:
	var layers: Array[TileMapLayer] = []
	var container := tilemap_container()
	if container == null:
		return layers
	for child: Node in container.get_children():
		if child is TileMapLayer:
			layers.append(child as TileMapLayer)
	return layers


func tilemap_container() -> Node2D:
	return get_node_or_null("TileMaps") as Node2D


func coordinate_layer() -> TileMapLayer:
	for layer: TileMapLayer in cell_flags:
		if cell_flags[layer] == CellState.CellFlag.BASE:
			return layer
	return null


func get_map_size() -> Vector2i:
	var base_layer := coordinate_layer()
	return base_layer.get_used_rect().size if base_layer != null else Vector2i.ZERO


func get_tile_size() -> Vector2i:
	var base_layer := coordinate_layer()
	return base_layer.tile_set.tile_size if base_layer != null and base_layer.tile_set != null else Vector2i.ZERO


func add_item(item: Item) -> Error:
	if item == null or item.state == null or item.meta == null or item.item_id() == &"":
		return ERR_INVALID_PARAMETER
	if items.has(item.item_id()):
		return ERR_ALREADY_EXISTS
	var host := _item_host_for_meta(item.meta)
	if host == null:
		return ERR_UNCONFIGURED
	if item.get_parent() == null:
		host.add_child(item)
	elif item.get_parent() != host:
		return ERR_ALREADY_EXISTS
	items[item.item_id()] = item
	return OK


func add_item_state(
	item_state: ItemState, coordinates: Vector2i = Vector2i.ZERO, trace_delay_seconds: float = 0.0
) -> Error:
	if _map_state == null or item_state == null or item_state.instance_id == &"":
		return ERR_INVALID_PARAMETER
	if _map_state.items.has(item_state.instance_id) or items.has(item_state.instance_id):
		return ERR_ALREADY_EXISTS
	var item_meta := DataCatalog.get_item(item_state.meta_id)
	if item_meta == null or not _state_matches_meta(item_state, item_meta):
		return ERR_INVALID_PARAMETER
	var cell := get_cell(coordinates)
	if cell == null:
		return ERR_DOES_NOT_EXIST
	var add_id_error := cell.add_item_id(item_state.instance_id)
	if add_id_error != OK:
		return add_id_error
	_map_state.items[item_state.instance_id] = item_state
	item_state.cell = coordinates
	var item := _create_item(item_state)
	var add_error := add_item(item)
	if add_error != OK:
		_map_state.items.erase(item_state.instance_id)
		var rollback_error := cell.remove_item_id(item_state.instance_id)
		assert(rollback_error == OK)
		return add_error
	item.set_trace_delay(trace_delay_seconds)
	interaction_revision += 1
	return OK


func create_item_instance_id(meta_id: StringName) -> StringName:
	var serial := 1
	var candidate := StringName("%s_%d" % [meta_id, serial])
	while items.has(candidate) or (_map_state != null and _map_state.items.has(candidate)):
		serial += 1
		candidate = StringName("%s_%d" % [meta_id, serial])
	return candidate


func spawn_pickup(meta_id: StringName, coordinates: Vector2i, trace_delay_seconds: float = 0.0) -> StringName:
	var item_meta := DataCatalog.get_item(meta_id)
	if (
		item_meta == null
		or item_meta is ToolMeta
		or not item_meta.can_pickup
		or not item_meta.dropable
		or get_cell(coordinates) == null
	):
		return &""
	var item_state := ItemState.new()
	item_state.meta_id = meta_id
	item_state.instance_id = create_item_instance_id(StringName("pickup_%s" % meta_id))
	item_state.cell = coordinates
	if add_item_state(item_state, coordinates, trace_delay_seconds) != OK:
		return &""
	return item_state.instance_id


func harvestable_at(coordinates: Vector2i) -> Harvestable:
	var cell := get_cell(coordinates)
	if cell == null:
		return null
	for item_id: StringName in cell.cell_state().item_ids:
		var harvestable := get_item(item_id) as Harvestable
		if harvestable != null:
			return harvestable
	return null


func check_cell(coordinates: Vector2i, condition: CellCondition) -> bool:
	var cell := get_cell(coordinates)
	if cell == null:
		return false
	var has_occupant := false
	for item_id: StringName in cell.cell_state().item_ids:
		var item := get_item(item_id)
		if item == null or not item.meta.can_pickup:
			has_occupant = true
			break
	match condition:
		CellCondition.HAS_OCCUPANT:
			return has_occupant
		CellCondition.PLANTABLE:
			return cell.is_dug() and not cell.has_static_flag(CellState.CellFlag.BLOCKED) and not has_occupant
		CellCondition.DROPABLE:
			return cell.is_dropable() and not has_occupant
	return false


func resolve_depleted_item(item_id: StringName, trace_delay_seconds: float = 0.0) -> Array[StringName]:
	var harvestable := get_item(item_id) as Harvestable
	var pickup_ids: Array[StringName] = []
	if harvestable == null or not harvestable.is_depleted():
		return pickup_ids
	var coordinates: Vector2i = harvestable.state.cell
	if coordinates == Vector2i(999999, 999999):
		return pickup_ids
	var replacement_id := (harvestable.get_meta() as HarvestableMeta).depleted_replacement_id
	var drops := roll_drops(harvestable.active_drops())
	var remove_error := remove_item(item_id)
	if remove_error != OK:
		return pickup_ids
	if replacement_id != &"":
		var replacement_meta := DataCatalog.get_item(replacement_id) as HarvestableMeta
		if replacement_meta != null:
			var replacement_state := HarvestableState.new()
			replacement_state.meta_id = replacement_id
			replacement_state.instance_id = create_item_instance_id(replacement_id)
			replacement_state.health = replacement_meta.health
			add_item_state(replacement_state, coordinates)
	for item_id_and_amount: Dictionary in drops:
		for _index in int(item_id_and_amount["amount"]):
			var pickup_id := spawn_pickup(
				item_id_and_amount["item_id"] as StringName, coordinates, trace_delay_seconds
			)
			if pickup_id != &"":
				pickup_ids.append(pickup_id)
	return pickup_ids


func roll_drops(entries: Array[HarvestableDrop]) -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	for entry: HarvestableDrop in entries:
		if entry != null and drop_rng.randf() <= entry.chance:
			drops.append({"item_id": entry.item_id, "amount": drop_rng.randi_range(entry.min_amount, entry.max_amount)})
	return drops


func settle_day(current_day: int) -> Array[StringName]:
	var grown: Array[StringName] = []
	if current_day <= 0:
		return grown
	for item_id: StringName in items:
		var plant := items[item_id] as Plant
		if plant == null or plant.get_state() == null:
			continue
		var cell := get_cell(plant.get_state().cell)
		if cell != null and cell.is_watered() and plant.grow_for_day(current_day):
			grown.append(item_id)
	clear_watered()
	return grown


func get_item(item_id: StringName) -> Item:
	return items.get(item_id, null) as Item


func move_item(item_id: StringName, target_coordinates: Vector2i) -> Error:
	var item := get_item(item_id)
	var target := get_cell(target_coordinates)
	if item == null or item.state == null:
		return ERR_DOES_NOT_EXIST
	if target == null:
		return ERR_INVALID_PARAMETER
	var source := get_cell(item.state.cell)
	if source == null or not source.has_item(item_id):
		return ERR_INVALID_DATA
	if source == target:
		return OK
	var remove_error := source.remove_item_id(item_id)
	if remove_error != OK:
		return remove_error
	var add_error := target.add_item_id(item_id)
	if add_error != OK:
		var rollback_error := source.add_item_id(item_id)
		assert(rollback_error == OK)
		return add_error
	item.state.cell = target_coordinates
	item.position = cell_to_world_center(target_coordinates)
	interaction_revision += 1
	return OK


func sync_item_cell_from_position(item_id: StringName) -> Error:
	var item := get_item(item_id)
	if item == null or item.state == null:
		return ERR_DOES_NOT_EXIST
	var target_coordinates := world_to_cell(item.global_position)
	if target_coordinates == item.state.cell:
		return OK
	if not contains_cell(target_coordinates):
		return ERR_INVALID_PARAMETER
	return move_item(item_id, target_coordinates)


func remove_item(item_id: StringName) -> Error:
	var item := get_item(item_id)
	if item == null or item.state == null or _map_state == null:
		return ERR_DOES_NOT_EXIST
	var cell := get_cell(item.state.cell)
	if cell == null:
		return ERR_INVALID_DATA
	var remove_error := cell.remove_item_id(item_id)
	if remove_error != OK:
		return remove_error
	items.erase(item_id)
	_map_state.items.erase(item_id)
	item.destroy()
	interaction_revision += 1
	return OK


func item_count() -> int:
	return items.size()


func world_to_cell(world_position: Vector2) -> Vector2i:
	var layer := coordinate_layer()
	if layer == null:
		return Vector2i(floori(world_position.x), floori(world_position.y))
	return layer.local_to_map(layer.to_local(world_position))


func cell_to_world_center(cell: Vector2i) -> Vector2:
	var layer := coordinate_layer()
	if layer == null:
		return Vector2(cell) + Vector2(0.5, 0.5)
	return layer.to_global(layer.map_to_local(cell))


func get_cells_in_rect(rect: Rect2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var clipped := rect.intersection(Rect2i(Vector2i.ZERO, get_map_size()))
	if clipped.size.x <= 0 or clipped.size.y <= 0:
		return result
	for y: int in range(clipped.position.y, clipped.end.y):
		for x: int in range(clipped.position.x, clipped.end.x):
			result.append(Vector2i(x, y))
	return result


func map_bounds_world() -> Rect2:
	var tile_size := get_tile_size()
	var top_left := cell_to_world_center(Vector2i.ZERO) - Vector2(tile_size) * 0.5
	return Rect2(top_left, Vector2(get_map_size() * tile_size))


func contains_cell(cell: Vector2i) -> bool:
	return cells.has(cell)


func get_cell(cell: Vector2i) -> MapCell:
	return cells.get(cell, null) as MapCell


func is_walkable(cell: Vector2i) -> bool:
	var map_cell := get_cell(cell)
	return map_cell != null and map_cell.is_walkable()


func commit_cell_changes(changed_cells: Array[Vector2i], synchronize_weather: bool = false) -> Error:
	if changed_cells.is_empty():
		return ERR_INVALID_PARAMETER
	for coordinates: Vector2i in changed_cells:
		if not cells.has(coordinates):
			return ERR_DOES_NOT_EXIST
	if synchronize_weather and _is_rainy_weather():
		for coordinates: Vector2i in changed_cells:
			var cell: MapCell = cells[coordinates]
			if cell.is_dug() and not cell.is_watered():
				cell.add_state_flag(CellState.CellFlag.WATERED)
	interaction_revision += 1
	return rebuild_cell_state_layers()


func clear_watered() -> Array[Vector2i]:
	var changed: Array[Vector2i] = []
	for coordinates: Vector2i in cells:
		var cell: MapCell = cells[coordinates]
		if cell.is_watered():
			cell.remove_state_flag(CellState.CellFlag.WATERED)
			changed.append(coordinates)
	if not changed.is_empty():
		commit_cell_changes(changed)
	return changed


func water_dug_cells_from_weather() -> Array[Vector2i]:
	var changed: Array[Vector2i] = []
	for coordinates: Vector2i in cells:
		var cell: MapCell = cells[coordinates]
		if cell.is_dug() and not cell.is_watered():
			cell.add_state_flag(CellState.CellFlag.WATERED)
			changed.append(coordinates)
	if not changed.is_empty():
		commit_cell_changes(changed)
	return changed


func _on_day_advanced(_previous_day: int, current_day: int) -> void:
	settle_day(current_day)
	call_deferred("_apply_current_weather")
	if _map_state == null or items_generator == null or not items_generator.regenerate_daily:
		return
	_map_state.generation_epoch += 1
	last_generation_summary = items_generator.generate(
		self, get_map_size(), _world_seed, _map_state.generation_epoch, _generated_trace_delay
	)
	var generation_error: Error = int(last_generation_summary.get("error", ERR_INVALID_DATA))
	if generation_error != OK:
		push_error("[BaseMap] daily generation failed for %s: %s" % [map_id, error_string(generation_error)])


func _on_weather_changed(weather_id: StringName, _previous_weather_id: StringName) -> void:
	if weather_id == &"rain" or weather_id == &"storm":
		call_deferred("water_dug_cells_from_weather")


func _apply_current_weather() -> void:
	if _is_rainy_weather():
		water_dug_cells_from_weather()


func _is_rainy_weather() -> bool:
	if not is_instance_valid(CalendarManager):
		return false
	return CalendarManager.current_weather_id() in [&"rain", &"storm"]


func rebuild_cell_state_layers() -> Error:
	if get_tile_size() == Vector2i.ZERO:
		return ERR_UNCONFIGURED
	_ensure_cell_state_layers()
	if _dug_layer == null or _watered_layer == null:
		return ERR_CANT_CREATE
	_dug_layer.clear()
	_watered_layer.clear()
	for coordinates: Vector2i in cells:
		var cell: MapCell = cells[coordinates]
		if cell.is_watered():
			_watered_layer.set_cell(coordinates, 0, Vector2i(3, 0), 0)
		elif cell.is_dug():
			_dug_layer.set_cell(coordinates, 0, Vector2i(1, 1), 0)
	return OK


func spawn_position(spawn_id: StringName) -> Vector2:
	if spawn_points != null:
		var marker := spawn_points.get_node_or_null(String(spawn_id)) as Marker2D
		if marker != null:
			return marker.global_position
	return cell_to_world_center(Vector2i(2, 2))


func _build_cells() -> void:
	cells.clear()
	for coordinates: Vector2i in get_cells_in_rect(Rect2i(Vector2i.ZERO, get_map_size())):
		cells[coordinates] = MapCell.new(coordinates)
	for layer: TileMapLayer in cell_flags:
		if layer == null:
			continue
		var flag: CellState.CellFlag = cell_flags[layer]
		for coordinates: Vector2i in layer.get_used_cells():
			var map_cell := get_cell(coordinates)
			if map_cell != null:
				map_cell.add_static_flag(flag)


func _ensure_cell_state_layers() -> void:
	var container := tilemap_container()
	if container == null:
		return
	_dug_layer = container.get_node_or_null("DugLayer") as TileMapLayer
	_watered_layer = container.get_node_or_null("WateredLayer") as TileMapLayer


func _create_item(item_state: ItemState) -> Item:
	var item_meta := DataCatalog.get_item(item_state.meta_id)
	if item_meta == null or not _state_matches_meta(item_state, item_meta):
		return null
	var host := _item_host_for_meta(item_meta)
	if host == null:
		return null
	var item := ItemManager.create_item(item_state, host)
	if item == null:
		return null
	item.position = cell_to_world_center(item_state.cell)
	return item


func _state_matches_meta(item_state: ItemState, item_meta: ItemMeta) -> bool:
	if item_state == null or item_meta == null:
		return false
	if item_meta is ToolMeta:
		return false
	if item_meta is PlantMeta:
		return item_state is PlantState
	if item_meta is HarvestableMeta:
		return item_state is HarvestableState
	return not item_state is HarvestableState


func _item_host_for_meta(item_meta: ItemMeta) -> Node2D:
	if item_meta is PlantMeta:
		return plants_host
	if item_meta is HarvestableMeta:
		return harvestables_host
	if item_meta is ToolMeta:
		return null
	return items_host


func _clear_items() -> void:
	for item: Item in items.values():
		if is_instance_valid(item):
			item.free()
	items.clear()
