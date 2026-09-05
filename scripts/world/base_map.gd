class_name BaseMap
extends Node2D

@export var map_id: StringName = &"farm"
@export var map_layers: Dictionary[CellState.CellFlag, TileMapLayer] = {}
@export var item_hosts: Dictionary[ItemMeta.ItemType, Node2D] = {}

var cells: Dictionary[Vector2i, MapCell] = {}
var items: Dictionary[StringName, Item] = {}
var interaction_revision: int = 0
var _map_state: MapState = null
var drop_rng: RandomNumberGenerator = RandomNumberGenerator.new()
@onready var spawn_points: Node2D = $SpawnPoints
@onready var item_generator: ItemGenerator = get_node_or_null("ItemGenerator") as ItemGenerator


func setup(map_state: MapState, run_generation: bool = false) -> Error:
	if map_state == null or map_state.map_id != map_id:
		return ERR_INVALID_PARAMETER
	if not EventBus.day_advanced.is_connected(_on_day_advanced):
		EventBus.day_advanced.connect(_on_day_advanced)
	if cells.is_empty():
		_build_cells()
	if cells.is_empty():
		return ERR_UNCONFIGURED
	var alignment_error := validate_alignment()
	if alignment_error != OK:
		return alignment_error
	var seen_item_ids: Dictionary[StringName, bool] = {}
	_map_state = map_state
	if map_state.cells.size() > cells.size():
		return ERR_INVALID_DATA
	for coordinates: Vector2i in cells:
		var map_cell: MapCell = cells[coordinates]
		var state := map_state.cells.get(coordinates, null) as CellState
		if state == null:
			state = map_cell.state
			map_state.cells[coordinates] = state
		if state.cell != coordinates:
			return ERR_INVALID_DATA
		var map_flags := map_cell.state.flags & ~CellState.PERSISTENT_FLAGS
		map_cell.state = state
		map_cell.state.cell = coordinates
		map_cell.state.flags |= map_flags
		for item_id: StringName in state.item_ids:
			var item_state := map_state.items.get(item_id, null) as ItemState
			if item_state == null or item_state.unique_id != item_id or seen_item_ids.has(item_id):
				return ERR_INVALID_DATA
			seen_item_ids[item_id] = true
			var item := ItemManager.create_from_state(item_state)
			if item == null:
				return ERR_INVALID_DATA
			var add_error := add_item(item, item_state.position)
			if add_error != OK:
				item.free()
				continue
	if map_state.cells.size() != cells.size():
		return ERR_INVALID_DATA
	if seen_item_ids.size() != map_state.items.size():
		return ERR_INVALID_DATA
	if run_generation and not map_state.generator_initialized:
		if item_generator == null:
			map_state.generator_initialized = true
		else:
			var generation_error := item_generator.generate(self)
			if generation_error != OK:
				return generation_error
			map_state.generator_initialized = true
	return rebuild_layers()


func validate_alignment() -> Error:
	if map_layers.is_empty() or not map_layers.has(CellState.CellFlag.BASE):
		return ERR_UNCONFIGURED
	var tile_size := get_tile_size()
	var map_size := get_map_size()
	if tile_size.x <= 0 or tile_size.y <= 0 or map_size.x <= 0 or map_size.y <= 0:
		return ERR_INVALID_DATA
	for layer: TileMapLayer in map_layers.values():
		if layer == null:
			return ERR_INVALID_DATA
		if layer.tile_set == null or layer.tile_set.tile_size != tile_size:
			return ERR_UNCONFIGURED
		if layer.position != Vector2.ZERO or layer.rotation != 0.0 or layer.scale != Vector2.ONE:
			return ERR_INVALID_DATA
	for flag: CellState.CellFlag in map_layers:
		var layer := map_layers[flag]
		if int(flag) == 0 or layer == null:
			return ERR_INVALID_DATA
		for coordinates: Vector2i in layer.get_used_cells():
			if not cells.has(coordinates):
				return ERR_INVALID_DATA
	if not map_layers.has(CellState.CellFlag.BASE):
		return ERR_INVALID_DATA
	if item_hosts.is_empty():
		return ERR_UNCONFIGURED
	for item_type: ItemMeta.ItemType in item_hosts:
		var host: Node2D = item_hosts[item_type]
		if item_type == ItemMeta.ItemType.TOOL or host == null or not is_ancestor_of(host):
			return ERR_INVALID_DATA
	return OK


func get_map_size() -> Vector2i:
	var base_layer := map_layers.get(CellState.CellFlag.BASE, null) as TileMapLayer
	return base_layer.get_used_rect().size if base_layer != null else Vector2i.ZERO


func get_tile_size() -> Vector2i:
	var base_layer := map_layers.get(CellState.CellFlag.BASE, null) as TileMapLayer
	return base_layer.tile_set.tile_size if base_layer != null and base_layer.tile_set != null else Vector2i.ZERO


func harvestable_at(coordinates: Vector2i) -> Harvestable:
	var cell := get_cell(coordinates)
	if cell == null:
		return null
	for item_id: StringName in cell.state.item_ids:
		var harvestable := get_item(item_id) as Harvestable
		if harvestable != null:
			return harvestable
	return null


func check_cell(coordinates: Vector2i, condition: CellState.CellCondition) -> bool:
	var cell := get_cell(coordinates)
	if cell == null:
		return false
	var has_occupant := false
	for item_id: StringName in cell.state.item_ids:
		var item := get_item(item_id)
		if item == null or not item.meta.can_pickup:
			has_occupant = true
			break
	match condition:
		CellState.CellCondition.WALKABLE:
			return cell.has_flag(CellState.CellFlag.BASE) and not cell.has_flag(CellState.CellFlag.BLOCKED)
		CellState.CellCondition.DIGGABLE:
			return cell.has_flag(CellState.CellFlag.DIGGABLE) and not cell.has_flag(CellState.CellFlag.BLOCKED)
		CellState.CellCondition.DUG:
			return cell.has_flag(CellState.CellFlag.DUG)
		CellState.CellCondition.WATERED:
			return cell.has_flag(CellState.CellFlag.WATERED)
		CellState.CellCondition.HAS_OCCUPANT:
			return has_occupant
		CellState.CellCondition.PLANTABLE:
			return (
				cell.has_flag(CellState.CellFlag.DUG)
				and not cell.has_flag(CellState.CellFlag.BLOCKED)
				and not has_occupant
			)
		CellState.CellCondition.DROPABLE:
			return (
				cell.has_flag(CellState.CellFlag.DROPABLE)
				and not cell.has_flag(CellState.CellFlag.BLOCKED)
				and not has_occupant
			)
	return false


func add_item(item: Item, item_position: Vector2) -> Error:
	if item == null or item.state == null or item.meta == null or item.item_id() == &"":
		return ERR_INVALID_PARAMETER
	if items.has(item.item_id()):
		return ERR_ALREADY_EXISTS
	var coordinates := world_to_cell(item_position)
	var cell := get_cell(coordinates)
	if cell == null:
		return ERR_DOES_NOT_EXIST
	var host := item_hosts.get(item.meta.item_type, null) as Node2D
	if host == null:
		return ERR_UNCONFIGURED
	if item.get_parent() == null:
		host.add_child(item)
	elif item.get_parent() != host:
		return ERR_ALREADY_EXISTS
	if not cell.has_item(item.item_id()):
		var cell_error := cell.add_item_id(item.item_id())
		if cell_error != OK:
			return cell_error
	if _map_state != null:
		_map_state.items[item.item_id()] = item.state
	items[item.item_id()] = item
	item.position = item_position
	item.state.position = item.position
	return OK


func get_item(item_id: StringName) -> Item:
	return items.get(item_id, null) as Item


func get_item_coord(item_id: StringName) -> Vector2i:
	var item := get_item(item_id)
	return world_to_cell(item.global_position) if item != null else Vector2i(999999, 999999)


func move_item(item_id: StringName, target_position: Vector2) -> Error:
	var item := get_item(item_id)
	if item == null or item.state == null:
		return ERR_DOES_NOT_EXIST
	var source := get_cell(world_to_cell(item.global_position))
	var target := get_cell(world_to_cell(target_position))
	if source == null or target == null or not source.has_item(item_id):
		return ERR_INVALID_DATA
	if source != target:
		var remove_error := source.remove_item_id(item_id)
		if remove_error != OK:
			return remove_error
		var add_error := target.add_item_id(item_id)
		if add_error != OK:
			var rollback_error := source.add_item_id(item_id)
			assert(rollback_error == OK)
			return add_error
		interaction_revision += 1
	item.global_position = target_position
	item.state.position = item.position
	return OK


func remove_item(item_id: StringName) -> Error:
	var item := get_item(item_id)
	if item == null or item.state == null or _map_state == null:
		return ERR_DOES_NOT_EXIST
	var cell := get_cell(get_item_coord(item_id))
	if cell == null:
		return ERR_INVALID_DATA
	var remove_error := cell.remove_item_id(item_id)
	if remove_error != OK:
		return remove_error
	items.erase(item_id)
	_map_state.items.erase(item_id)
	ItemManager.unregister_pickup(item)
	item.destroy()
	return OK


func resolve_depleted_item(item_id: StringName) -> Array[StringName]:
	var harvestable := get_item(item_id) as Harvestable
	var pickup_ids: Array[StringName] = []
	if harvestable == null or not harvestable.is_depleted():
		return pickup_ids
	var coordinates := get_item_coord(item_id)
	if coordinates == Vector2i(999999, 999999):
		return pickup_ids
	var harvestable_meta := harvestable.meta as HarvestableMeta
	if harvestable_meta == null:
		return pickup_ids
	var replacement_id := harvestable_meta.depleted_replacement_id
	var drop_entries := harvestable.active_drops()
	var drop_delay := float(DataCatalog.config.player_trace_delay.get(&"drop", 0.0))
	for entry: HarvestableDrop in drop_entries.values():
		if entry == null or drop_rng.randf() > entry.chance:
			continue
		var amount := drop_rng.randi_range(entry.min_amount, entry.max_amount)
		for _index in amount:
			var drop_item := ItemManager.create_from_id(entry.item_id)
			if drop_item == null:
				continue
			if add_item(drop_item, cell_to_world(coordinates, false)) != OK:
				drop_item.free()
				continue
			drop_item.set_trace_delay(drop_delay)
			drop_item.state.add_flag(ItemMeta.ItemFlag.DROPPED)
			pickup_ids.append(drop_item.item_id())
	var remove_error := remove_item(item_id)
	if remove_error != OK:
		return pickup_ids
	if replacement_id != &"":
		var replacement := ItemManager.create_from_id(replacement_id)
		if replacement != null:
			if add_item(replacement, harvestable.position) != OK:
				replacement.free()
	return pickup_ids


func world_to_cell(world_position: Vector2) -> Vector2i:
	var layer := map_layers.get(CellState.CellFlag.BASE, null) as TileMapLayer
	if layer == null:
		return Vector2i(floori(world_position.x), floori(world_position.y))
	return layer.local_to_map(layer.to_local(world_position))


func cell_to_world(cell: Vector2i, in_center: bool = true) -> Vector2:
	var layer := map_layers.get(CellState.CellFlag.BASE, null) as TileMapLayer
	if layer == null:
		return Vector2(cell) + (Vector2(0.5, 0.5) if in_center else Vector2(randf(), randf()))
	var center := layer.to_global(layer.map_to_local(cell))
	if in_center:
		return center
	var tile_size := Vector2(get_tile_size())
	return center + Vector2(randf_range(-tile_size.x * 0.5, tile_size.x * 0.5), randf_range(-tile_size.y * 0.5, tile_size.y * 0.5))


func get_cell(cell: Vector2i) -> MapCell:
	return cells.get(cell, null) as MapCell


func generation_epoch() -> int:
	return _map_state.generation_epoch if _map_state != null else -1


func rebuild_layers() -> Error:
	interaction_revision += 1
	if get_tile_size() == Vector2i.ZERO:
		return ERR_UNCONFIGURED
	var dug_layer := map_layers.get(CellState.CellFlag.DUG, null) as TileMapLayer
	var watered_layer := map_layers.get(CellState.CellFlag.WATERED, null) as TileMapLayer
	if dug_layer == null or watered_layer == null:
		return ERR_CANT_CREATE
	dug_layer.clear()
	watered_layer.clear()
	for coordinates: Vector2i in cells:
		if check_cell(coordinates, CellState.CellCondition.WATERED):
			watered_layer.set_cell(coordinates, 0, Vector2i(3, 0), 0)
		elif check_cell(coordinates, CellState.CellCondition.DUG):
			dug_layer.set_cell(coordinates, 0, Vector2i(1, 1), 0)
	return OK


func spawn_position(spawn_id: StringName) -> Vector2:
	if spawn_points != null:
		var marker := spawn_points.get_node_or_null(String(spawn_id)) as Marker2D
		if marker != null:
			return marker.global_position
	return cell_to_world(Vector2i(2, 2))


func _build_cells() -> void:
	cells.clear()
	var base_layer := map_layers.get(CellState.CellFlag.BASE, null) as TileMapLayer
	if base_layer == null:
		return
	for coordinates: Vector2i in base_layer.get_used_cells():
		cells[coordinates] = MapCell.new(coordinates)
	for flag: CellState.CellFlag in map_layers:
		var layer := map_layers[flag]
		if layer == null:
			continue
		for coordinates: Vector2i in layer.get_used_cells():
			var map_cell := get_cell(coordinates)
			if map_cell != null:
				map_cell.add_flag(flag)


func _on_day_advanced() -> void:
	var current_day := CalendarManager.calendar.day
	if current_day <= 0:
		return
	for item_id: StringName in items:
		var plant := items[item_id] as Plant
		if plant == null or plant.state == null:
			continue
		if check_cell(get_item_coord(item_id), CellState.CellCondition.WATERED):
			plant.grow(current_day)
	var is_rainy := CalendarManager.check_weather([&"rain", &"storm"])
	var changed_cells: Array[Vector2i] = []
	for coordinates: Vector2i in cells:
		var cell: MapCell = cells[coordinates]
		var should_be_watered := is_rainy and cell.has_flag(CellState.CellFlag.DUG)
		var is_watered := cell.has_flag(CellState.CellFlag.WATERED)
		if should_be_watered == is_watered:
			continue
		if should_be_watered:
			cell.add_flag(CellState.CellFlag.WATERED)
		else:
			cell.remove_flag(CellState.CellFlag.WATERED)
		changed_cells.append(coordinates)
	if not changed_cells.is_empty():
		rebuild_layers()
	if _map_state == null or item_generator == null or not item_generator.regenerate_daily:
		return
	_map_state.generation_epoch += 1
	var generation_error := item_generator.generate(self)
	if generation_error != OK:
		push_error("[BaseMap] daily generation failed for %s: %s" % [map_id, error_string(generation_error)])
