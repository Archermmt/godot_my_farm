class_name BaseMap
extends Node2D

@export var map_id: StringName = &"farm"
@export var map_size: Vector2i = Vector2i(30, 20)
@export var tile_size: Vector2i = Vector2i(32, 32)
@export var cell_flags: Dictionary[TileMapLayer, CellState.CellFlag] = {}
@export var entity_hosts: Dictionary[Node2D, EntityState.EntityType] = {}

var cells: Dictionary[Vector2i, MapCell] = {}
var entities: Dictionary[StringName, Entity] = {}
var _map_state: MapState = null
@onready var spawn_points: Node2D = $SpawnPoints

func _ready() -> void:
	_build_cells()

func configure_state(map_state: MapState) -> Error:
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
	var seen_entity_ids: Dictionary[StringName, bool] = {}
	for coordinates: Vector2i in map_state.cells:
		var state: CellState = map_state.cells[coordinates]
		for entity_id: StringName in state.entity_ids:
			var entity_state := map_state.entities.get(entity_id, null) as EntityState
			if entity_state == null or entity_state.instance_id != entity_id or entity_state.cell != coordinates or seen_entity_ids.has(entity_id):
				return ERR_INVALID_DATA
			seen_entity_ids[entity_id] = true
	if seen_entity_ids.size() != map_state.entities.size():
		return ERR_INVALID_DATA
	var restored_entities: Array[Entity] = []
	for entity_id: StringName in map_state.entities:
		var entity_state: EntityState = map_state.entities[entity_id]
		if entity_state == null or entity_state.instance_id != entity_id or entity_state.type == EntityState.EntityType.NONE or entity_state.type == EntityState.EntityType.NPC:
			return ERR_INVALID_DATA
		if entity_host(entity_state.type) == null:
			return ERR_UNCONFIGURED
		var entity := _create_entity(entity_state)
		if entity == null:
			return ERR_INVALID_DATA
		restored_entities.append(entity)
	_clear_entities()
	for coordinates: Vector2i in cells:
		var bind_error := cells[coordinates].bind_state(map_state.cells[coordinates])
		if bind_error != OK:
			return bind_error
	_map_state = map_state
	for entity: Entity in restored_entities:
		var add_error := add_entity(entity)
		if add_error != OK:
			_clear_entities()
			return add_error
	return OK

func validate_alignment() -> Error:
	if tile_size.x <= 0 or tile_size.y <= 0 or map_size.x <= 0 or map_size.y <= 0:
		return ERR_INVALID_DATA
	var layers := managed_layers()
	if layers.is_empty() or coordinate_layer() == null:
		return ERR_UNCONFIGURED
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
	var configured_entity_types: Dictionary[EntityState.EntityType, bool] = {}
	for host: Node2D in entity_hosts:
		var entity_type: EntityState.EntityType = entity_hosts[host]
		if host == null or not is_ancestor_of(host) or entity_type == EntityState.EntityType.NONE or configured_entity_types.has(entity_type):
			return ERR_INVALID_DATA
		configured_entity_types[entity_type] = true
	return OK

func managed_layers() -> Array[TileMapLayer]:
	var layers: Array[TileMapLayer] = []
	for child: Node in get_children():
		if child is TileMapLayer:
			layers.append(child as TileMapLayer)
	return layers

func coordinate_layer() -> TileMapLayer:
	for layer: TileMapLayer in cell_flags:
		if cell_flags[layer] == CellState.CellFlag.BASE:
			return layer
	return null

func entity_host(entity_type: EntityState.EntityType) -> Node2D:
	for host: Node2D in entity_hosts:
		if entity_hosts[host] == entity_type:
			return host
	return null

func add_entity(entity: Entity) -> Error:
	if entity == null or entity.state == null or entity.entity_id() == &"":
		return ERR_INVALID_PARAMETER
	if entities.has(entity.entity_id()) or entity.get_parent() != null:
		return ERR_ALREADY_EXISTS
	var host := entity_host(entity.type)
	if host == null:
		return ERR_UNCONFIGURED
	host.add_child(entity)
	entities[entity.entity_id()] = entity
	return OK

func add_entity_state(entity_state: EntityState) -> Error:
	if _map_state == null or entity_state == null or entity_state.instance_id == &"":
		return ERR_INVALID_PARAMETER
	if _map_state.entities.has(entity_state.instance_id) or entities.has(entity_state.instance_id):
		return ERR_ALREADY_EXISTS
	if entity_state.type == EntityState.EntityType.NONE or entity_state.type == EntityState.EntityType.NPC:
		return ERR_INVALID_PARAMETER
	var cell := get_cell(entity_state.cell)
	if cell == null:
		return ERR_DOES_NOT_EXIST
	var add_id_error := cell.add_entity_id(entity_state.instance_id)
	if add_id_error != OK:
		return add_id_error
	_map_state.entities[entity_state.instance_id] = entity_state
	var entity := _create_entity(entity_state)
	var add_error := add_entity(entity)
	if add_error != OK:
		_map_state.entities.erase(entity_state.instance_id)
		var rollback_error := cell.remove_entity_id(entity_state.instance_id)
		assert(rollback_error == OK)
		return add_error
	return OK


func get_entity(entity_id: StringName) -> Entity:
	return entities.get(entity_id, null) as Entity


func move_entity(entity_id: StringName, target_coordinates: Vector2i) -> Error:
	var entity := get_entity(entity_id)
	var target := get_cell(target_coordinates)
	if entity == null or entity.state == null:
		return ERR_DOES_NOT_EXIST
	if target == null:
		return ERR_INVALID_PARAMETER
	var source := get_cell(entity.state.cell)
	if source == null or not source.has_entity(entity_id):
		return ERR_INVALID_DATA
	if source == target:
		return OK
	var remove_error := source.remove_entity_id(entity_id)
	if remove_error != OK:
		return remove_error
	var add_error := target.add_entity_id(entity_id)
	if add_error != OK:
		var rollback_error := source.add_entity_id(entity_id)
		assert(rollback_error == OK)
		return add_error
	entity.state.cell = target_coordinates
	entity.position = cell_to_world_center(target_coordinates)
	return OK


func remove_entity(entity_id: StringName) -> Error:
	var entity := get_entity(entity_id)
	if entity == null or entity.state == null or _map_state == null:
		return ERR_DOES_NOT_EXIST
	var cell := get_cell(entity.state.cell)
	if cell == null:
		return ERR_INVALID_DATA
	var remove_error := cell.remove_entity_id(entity_id)
	if remove_error != OK:
		return remove_error
	entities.erase(entity_id)
	_map_state.entities.erase(entity_id)
	entity.queue_free()
	return OK

func entity_count(entity_type: EntityState.EntityType = EntityState.EntityType.NONE) -> int:
	if entity_type != EntityState.EntityType.NONE:
		var host := entity_host(entity_type)
		return host.get_child_count() if host != null else 0
	var count := 0
	for host: Node2D in entity_hosts:
		count += host.get_child_count()
	return count

func world_to_cell(world_position: Vector2) -> Vector2i:
	var layer := coordinate_layer()
	return layer.local_to_map(layer.to_local(world_position))

func cell_to_world_center(cell: Vector2i) -> Vector2:
	var layer := coordinate_layer()
	return layer.to_global(layer.map_to_local(cell))

func get_cells_in_rect(rect: Rect2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var clipped := rect.intersection(Rect2i(Vector2i.ZERO, map_size))
	if clipped.size.x <= 0 or clipped.size.y <= 0:
		return result
	for y: int in range(clipped.position.y, clipped.end.y):
		for x: int in range(clipped.position.x, clipped.end.x):
			result.append(Vector2i(x, y))
	return result

func map_bounds_world() -> Rect2:
	var top_left := cell_to_world_center(Vector2i.ZERO) - Vector2(tile_size) * 0.5
	return Rect2(top_left, Vector2(map_size * tile_size))

func contains_cell(cell: Vector2i) -> bool:
	return cells.has(cell)

func get_cell(cell: Vector2i) -> MapCell:
	return cells.get(cell, null) as MapCell

func has_cell_flag(cell: Vector2i, flag: CellState.CellFlag) -> bool:
	var map_cell := get_cell(cell)
	return map_cell != null and map_cell.has_flag(flag)

func is_walkable(cell: Vector2i) -> bool:
	var map_cell := get_cell(cell)
	return map_cell != null and map_cell.is_walkable()

func spawn_position(spawn_id: StringName) -> Vector2:
	if spawn_points != null:
		var marker := spawn_points.get_node_or_null(String(spawn_id)) as Marker2D
		if marker != null:
			return marker.global_position
	return cell_to_world_center(Vector2i(2, 2))

func _build_cells() -> void:
	cells.clear()
	for coordinates: Vector2i in get_cells_in_rect(Rect2i(Vector2i.ZERO, map_size)):
		cells[coordinates] = MapCell.new(coordinates)
	for layer: TileMapLayer in cell_flags:
		if layer == null:
			continue
		var flag: CellState.CellFlag = cell_flags[layer]
		for coordinates: Vector2i in layer.get_used_cells():
			var map_cell := get_cell(coordinates)
			if map_cell != null:
				map_cell.add_flag(flag)


func _create_entity(entity_state: EntityState) -> Entity:
	var entity: Entity = CropEntity.new() if entity_state.type == EntityState.EntityType.CROP else Entity.new()
	if entity.bind_state(entity_state) != OK:
		entity.free()
		return null
	entity.position = cell_to_world_center(entity_state.cell)
	return entity


func _clear_entities() -> void:
	for entity: Entity in entities.values():
		if is_instance_valid(entity):
			entity.free()
	entities.clear()
