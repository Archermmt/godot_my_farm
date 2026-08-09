class_name BaseMap
extends Node2D

@export var map_id: StringName = &"farm"
@export var map_size: Vector2i = Vector2i(30, 20)
@export var tile_size: Vector2i = Vector2i(32, 32)
@export var cell_status: Dictionary[TileMapLayer, MapCell.Status] = {}
@export var entity_hosts: Dictionary[Node2D, Entity.Type] = {}

var cells: Dictionary[Vector2i, MapCell] = {}
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
		var map_cell: MapCell = cells[coordinates]
		var configured_status := map_cell.status()
		var state := map_state.cells.get(coordinates, null) as CellState
		if state == null:
			state = CellState.new()
			state.cell = coordinates
			var set_error := map_state.set_cell(state)
			assert(set_error == OK)
		state.status = configured_status
		var bind_error := map_cell.bind_state(state)
		assert(bind_error == OK)
	_map_state = map_state
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
	if cell_status.is_empty():
		return ERR_UNCONFIGURED
	var base_layer_count := 0
	for layer: TileMapLayer in cell_status:
		if layer == null or layer not in layers or int(cell_status[layer]) == 0:
			return ERR_INVALID_DATA
		if cell_status[layer] == MapCell.Status.BASE:
			base_layer_count += 1
		for coordinates: Vector2i in layer.get_used_cells():
			if not contains_cell(coordinates):
				return ERR_INVALID_DATA
	if base_layer_count != 1:
		return ERR_INVALID_DATA
	var configured_entity_types: Dictionary[Entity.Type, bool] = {}
	for host: Node2D in entity_hosts:
		var entity_type: Entity.Type = entity_hosts[host]
		if host == null or not is_ancestor_of(host) or entity_type == Entity.Type.NONE or configured_entity_types.has(entity_type):
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
	for layer: TileMapLayer in cell_status:
		if cell_status[layer] == MapCell.Status.BASE:
			return layer
	return null

func entity_host(entity_type: Entity.Type) -> Node2D:
	for host: Node2D in entity_hosts:
		if entity_hosts[host] == entity_type:
			return host
	return null

func add_entity(entity: Entity) -> Error:
	if entity == null:
		return ERR_INVALID_PARAMETER
	var host := entity_host(entity.type)
	if host == null:
		return ERR_UNCONFIGURED
	if entity.get_parent() != null:
		return ERR_INVALID_PARAMETER
	host.add_child(entity)
	return OK

func entity_count(entity_type: Entity.Type = Entity.Type.NONE) -> int:
	if entity_type != Entity.Type.NONE:
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

func has_cell_status(cell: Vector2i, status: MapCell.Status) -> bool:
	var map_cell := get_cell(cell)
	return map_cell != null and map_cell.has_status(status)

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
	for layer: TileMapLayer in cell_status:
		if layer == null:
			continue
		var status: MapCell.Status = cell_status[layer]
		for coordinates: Vector2i in layer.get_used_cells():
			var map_cell := get_cell(coordinates)
			if map_cell != null:
				map_cell.add_status(status)
