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


func _ready() -> void:
	if not EventBus.day_advanced.is_connected(_on_day_advanced):
		EventBus.day_advanced.connect(_on_day_advanced)
	if get_map_size() == Vector2i.ZERO:
		push_error("[BaseMap] %s has no base layer" % map_id)
		return
	var alignment_error := validate_alignment()
	if alignment_error != OK:
		push_error("[BaseMap] invalid map configuration for %s: %s" % [map_id, error_string(alignment_error)])


func from_state(map_state: MapState) -> Error:
	if map_state == null or map_state.map_id != map_id:
		return ERR_INVALID_PARAMETER
	cells.clear()
	items.clear()
	if get_map_size() == Vector2i.ZERO:
		return ERR_UNCONFIGURED
	var alignment_error := validate_alignment()
	if alignment_error != OK:
		return alignment_error
	var seen_item_ids: Dictionary[StringName, bool] = {}
	_map_state = map_state
	for coordinates: Vector2i in map_state.cells:
		if not has_static_cell(coordinates):
			return ERR_INVALID_DATA
		var state := map_state.cells[coordinates] as CellState
		if state == null or state.coord != coordinates:
			return ERR_INVALID_DATA
		var map_cell := MapCell.new()
		if map_cell.from_state(state) != OK:
			return ERR_INVALID_DATA
		_apply_static_flags(map_cell)
		cells[coordinates] = map_cell
	for item_id: StringName in map_state.items:
		var item_state := map_state.items[item_id] as ItemState
		if item_state == null or item_state.unique_id != item_id or seen_item_ids.has(item_id):
			return ERR_INVALID_DATA
		seen_item_ids[item_id] = true
		var item := ItemManager.create_from_state(item_state)
		if item == null or add_item(item, item_state.position) != OK:
			if item != null:
				item.free()
			return ERR_INVALID_DATA
	if not map_state.generated:
		if item_generator == null:
			map_state.generated = true
		else:
			var generation_error := item_generator.generate(self)
			if generation_error != OK:
				return generation_error
			map_state.generated = true
	return rebuild_layers()


func to_state() -> MapState:
	if _map_state == null:
		_map_state = MapState.new()
		_map_state.map_id = map_id
	_map_state.cells.clear()
	_map_state.items.clear()
	for coordinates: Vector2i in cells:
		var map_cell := cells[coordinates] as MapCell
		if map_cell == null:
			continue
		if (map_cell.state.flags & CellState.PERSISTENT_FLAGS) != 0:
			_map_state.cells[coordinates] = map_cell.to_state()
	for item_id: StringName in items:
		var item := items[item_id]
		var item_state := item.to_state() if item != null else null
		if item_state != null:
			_map_state.items[item_id] = item_state
	return _map_state


func validate_alignment() -> Error:
	if map_layers.is_empty() or not map_layers.has(CellState.CellFlag.BASE):
		return ERR_UNCONFIGURED
	var tile_size := get_tile_size()
	var map_size := get_map_size()
	if tile_size.x <= 0 or tile_size.y <= 0 or map_size.x <= 0 or map_size.y <= 0:
		return ERR_INVALID_DATA
	for layer: TileMapLayer in map_layers.values():
		if layer == null:
			continue
		if layer.tile_set == null or layer.tile_set.tile_size != tile_size:
			return ERR_UNCONFIGURED
		if layer.position != Vector2.ZERO or layer.rotation != 0.0 or layer.scale != Vector2.ONE:
			return ERR_INVALID_DATA
	for flag: CellState.CellFlag in map_layers:
		var layer := map_layers[flag]
		if int(flag) == 0:
			return ERR_INVALID_DATA
		if layer == null:
			continue
		for coordinates: Vector2i in layer.get_used_cells():
			if not has_static_cell(coordinates):
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


func check_cell(coordinates: Vector2i, condition: CellState.CellCondition) -> bool:
	if not has_static_cell(coordinates):
		return false
	var is_blocked := has_flag(coordinates, CellState.CellFlag.BLOCKED)
	match condition:
		CellState.CellCondition.WALKABLE:
			return has_flag(coordinates, CellState.CellFlag.BASE) and not is_blocked
		CellState.CellCondition.DIGGABLE:
			return has_flag(coordinates, CellState.CellFlag.DIGGABLE) and not is_blocked
		CellState.CellCondition.DUG:
			return has_flag(coordinates, CellState.CellFlag.DUG)
		CellState.CellCondition.WATERED:
			return has_flag(coordinates, CellState.CellFlag.WATERED)
		CellState.CellCondition.HAS_OCCUPANT:
			return is_blocked
		CellState.CellCondition.PLANTABLE:
			var cell := get_cell(coordinates)
			# Tilled soil can only receive a seed when the cell has no item at all.
			# Relying only on BLOCKED misses plants/items restored from state or
			# items whose movement blocking rules changed.
			return (
				has_flag(coordinates, CellState.CellFlag.DUG)
				and not is_blocked
				and cell != null
				and cell.state.item_ids.is_empty()
			)
		CellState.CellCondition.DROPABLE:
			return has_flag(coordinates, CellState.CellFlag.DROPABLE) and not is_blocked
	return false


func _item_blocks_cell(item: Item) -> bool:
	if item == null or item.meta == null:
		return false
	var harvestable_meta := item.meta as HarvestableMeta
	return harvestable_meta.blocks_movement if harvestable_meta != null else not item.meta.can_pickup


func get_item(item_id: StringName) -> Item:
	return items.get(item_id, null) as Item


func get_item_coord(item_id: StringName) -> Vector2i:
	var item := get_item(item_id)
	return world_to_cell(item.global_position) if item != null else Vector2i(999999, 999999)


func add_item(item: Item, item_position: Vector2) -> Error:
	if item == null or item.state == null or item.meta == null or item.item_id() == &"":
		return ERR_INVALID_PARAMETER
	if items.has(item.item_id()):
		return ERR_ALREADY_EXISTS
	var coordinates := world_to_cell(item_position)
	if not has_static_cell(coordinates):
		return ERR_DOES_NOT_EXIST
	var host := item_hosts.get(item.meta.item_type, null) as Node2D
	if host == null:
		return ERR_UNCONFIGURED
	if item.get_parent() == null:
		host.add_child(item)
	elif item.get_parent() != host:
		return ERR_ALREADY_EXISTS
	if _map_state != null:
		_map_state.items[item.item_id()] = item.state
	items[item.item_id()] = item
	item.position = item_position
	if not item.meta.can_pickup:
		var map_cell := ensure_cell(coordinates)
		if map_cell != null:
			if item.item_id() not in map_cell.state.item_ids:
				map_cell.state.item_ids.append(item.item_id())
			if _item_blocks_cell(item):
				map_cell.add_flag(CellState.CellFlag.BLOCKED)
	if item.meta.can_pickup:
		var trace_key: StringName = &""
		if item.has_flag(ItemMeta.ItemFlag.DROPPED):
			trace_key = &"drop"
		elif item.has_flag(ItemMeta.ItemFlag.GENERATED):
			trace_key = &"generate"
		if trace_key != &"":
			item.set_trace_delay(float(DataCatalog.config.player_trace_delay.get(trace_key, 0.0)))
	return OK


func remove_item(item_id: StringName) -> Error:
	var item := get_item(item_id)
	if item == null or item.state == null or _map_state == null:
		return ERR_DOES_NOT_EXIST
	items.erase(item_id)
	_map_state.items.erase(item_id)
	var coordinates := world_to_cell(item.global_position)
	var blocks_cell := _item_blocks_cell(item)
	ItemManager.unregister_pickup(item)
	item.destroy()
	if not item.meta.can_pickup:
		var map_cell := get_cell(coordinates)
		if map_cell != null:
			map_cell.state.item_ids.erase(item_id)
			if blocks_cell:
				var still_blocked := false
				for remaining_id: StringName in map_cell.state.item_ids:
					var remaining_item := get_item(remaining_id)
					if _item_blocks_cell(remaining_item):
						still_blocked = true
						break
				if not still_blocked:
					map_cell.remove_flag(CellState.CellFlag.BLOCKED)
			_prune_cell(coordinates)
	return OK


func resolve_depleted_item(item_id: StringName, collector: FarmPlayer = null) -> Array[StringName]:
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
	for entry: HarvestableDrop in drop_entries.values():
		if entry == null or drop_rng.randf() > entry.chance:
			continue
		var amount := drop_rng.randi_range(entry.min_amount, entry.max_amount)
		for _index in amount:
			var drop_item := ItemManager.create_from_id(entry.item_id)
			if drop_item == null:
				continue
			if collector != null and drop_item.meta != null:
				if collector.collect_item(drop_item.meta, 1) > 0:
					pickup_ids.append(drop_item.item_id())
					drop_item.free()
					continue
			drop_item.add_flag(ItemMeta.ItemFlag.DROPPED)
			if add_item(drop_item, cell_to_world(coordinates, false)) != OK:
				drop_item.free()
				continue
			pickup_ids.append(drop_item.item_id())
	var plant := harvestable as Plant
	var return_health := harvestable_meta.harvest_return_health if plant != null else 0
	if return_health > 0 and plant != null:
		plant.state.health = mini(return_health, harvestable_meta.health)
		plant.refresh_stage_visual()
	else:
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
	return (
		center
		+ Vector2(
			randf_range(-tile_size.x * 0.5, tile_size.x * 0.5), randf_range(-tile_size.y * 0.5, tile_size.y * 0.5)
		)
	)


func get_cell(cell: Vector2i) -> MapCell:
	return cells.get(cell, null) as MapCell


func ensure_cell(coordinates: Vector2i) -> MapCell:
	var map_cell := get_cell(coordinates)
	if map_cell == null and has_static_cell(coordinates):
		var state := CellState.new()
		state.coord = coordinates
		map_cell = MapCell.new()
		map_cell.from_state(state)
		_apply_static_flags(map_cell)
		cells[coordinates] = map_cell
		if _map_state != null:
			_map_state.cells[coordinates] = map_cell.to_state()
	return map_cell


func has_static_cell(coordinates: Vector2i) -> bool:
	var base_layer := map_layers.get(CellState.CellFlag.BASE, null) as TileMapLayer
	return base_layer != null and base_layer.get_cell_source_id(coordinates) != -1


func has_flag(coordinates: Vector2i, flag: CellState.CellFlag) -> bool:
	var map_cell := get_cell(coordinates)
	if map_cell != null and map_cell.has_flag(flag):
		return true
	var layer := map_layers.get(flag, null) as TileMapLayer
	return layer != null and layer.get_cell_source_id(coordinates) != -1


func _apply_static_flags(map_cell: MapCell) -> void:
	for flag: CellState.CellFlag in map_layers:
		if (int(flag) & CellState.PERSISTENT_FLAGS) != 0:
			continue
		var layer := map_layers[flag] as TileMapLayer
		if layer != null and layer.get_cell_source_id(map_cell.coord) != -1:
			map_cell.add_flag(flag)


func _prune_cell(coordinates: Vector2i) -> void:
	var map_cell := get_cell(coordinates)
	if map_cell == null:
		return
	if (map_cell.state.flags & CellState.PERSISTENT_FLAGS) != 0 or not map_cell.state.item_ids.is_empty():
		return
	cells.erase(coordinates)
	if _map_state != null:
		_map_state.cells.erase(coordinates)


func generation_epoch() -> int:
	return _map_state.generation_epoch if _map_state != null else -1


func rebuild_layers(changed_cells: Array[Vector2i] = []) -> Error:
	interaction_revision += 1
	if get_tile_size() == Vector2i.ZERO:
		return ERR_UNCONFIGURED
	var dug_layer := map_layers.get(CellState.CellFlag.DUG, null) as TileMapLayer
	var watered_layer := map_layers.get(CellState.CellFlag.WATERED, null) as TileMapLayer
	if dug_layer == null or watered_layer == null:
		return ERR_CANT_CREATE
	var coordinates_to_update: Array[Vector2i] = changed_cells
	if coordinates_to_update.is_empty():
		dug_layer.clear()
		watered_layer.clear()
		coordinates_to_update = cells.keys()
	for coordinates: Vector2i in coordinates_to_update:
		if not cells.has(coordinates):
			dug_layer.erase_cell(coordinates)
			watered_layer.erase_cell(coordinates)
			continue
		dug_layer.erase_cell(coordinates)
		watered_layer.erase_cell(coordinates)
		if check_cell(coordinates, CellState.CellCondition.WATERED):
			watered_layer.set_cell(coordinates, 0, Vector2i(1, 1), 0)
		elif check_cell(coordinates, CellState.CellCondition.DUG):
			dug_layer.set_cell(coordinates, 0, Vector2i(1, 0), 0)
	return OK


func spawn_position(spawn_id: StringName) -> Vector2:
	if spawn_points != null:
		var marker := spawn_points.get_node_or_null(String(spawn_id)) as Marker2D
		if marker != null:
			return marker.global_position
	return cell_to_world(Vector2i(2, 2))


func _on_day_advanced() -> void:
	var current_day := CalendarManager.calendar.day
	if current_day <= 0:
		return
	for item_id: StringName in items:
		var plant := items[item_id] as Plant
		if plant == null or plant.state == null:
			continue
		var plant_meta := plant.meta as PlantMeta
		var watered := check_cell(get_item_coord(item_id), CellState.CellCondition.WATERED)
		var plant_state := plant.state as PlantState
		var before_health := plant_state.health if plant_state != null else -1
		var before_growth_day := plant_state.last_growth_day if plant_state != null else -1
		var did_grow := false
		if plant_meta == null or not plant_meta.requires_water or watered:
			did_grow = plant.grow(current_day)
		var display_name := plant_meta.display_name if plant_meta != null and not plant_meta.display_name.is_empty() else String(plant.item_id())
		var after_health := plant_state.health if plant_state != null else -1
		var after_growth_day := plant_state.last_growth_day if plant_state != null else -1
		GameManager.debug(
			"[PlantGrowth] map=%s plant=%s id=%s day=%d watered=%s health=%d->%d growth_day=%d->%d grew=%s"
			% [
				map_id,
				display_name,
				plant.item_id(),
				current_day,
				watered,
				before_health,
				after_health,
				before_growth_day,
				after_growth_day,
				did_grow,
			]
		)
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
		rebuild_layers(changed_cells)
	if _map_state == null or item_generator == null or not item_generator.regenerate_daily:
		return
	_map_state.generation_epoch += 1
	var generation_error := item_generator.generate(self)
	if generation_error != OK:
		push_error("[BaseMap] daily generation failed for %s: %s" % [map_id, error_string(generation_error)])
