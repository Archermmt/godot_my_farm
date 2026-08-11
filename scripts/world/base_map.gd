class_name BaseMap
extends Node2D

@export var map_id: StringName = &"farm"
@export var cell_flags: Dictionary[TileMapLayer, CellState.CellFlag] = {}
@export var item_hosts: Dictionary[Node2D, ItemMeta.WorldType] = {}

var cells: Dictionary[Vector2i, MapCell] = {}
var items: Dictionary[StringName, Item] = {}
var interaction_revision: int = 0
var _map_state: MapState = null
var _cell_state_projection: Node2D = null
var _catalog_service: DataCatalogService = null
@onready var spawn_points: Node2D = $SpawnPoints

func _ready() -> void:
	configure_services(DataCatalog)
	_build_cells()
	_ensure_cell_state_projection()


func configure_services(catalog_service: DataCatalogService) -> void:
	_catalog_service = catalog_service

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
	var seen_item_ids: Dictionary[StringName, bool] = {}
	for coordinates: Vector2i in map_state.cells:
		var state: CellState = map_state.cells[coordinates]
		for item_id: StringName in state.item_ids:
			var item_state := map_state.items.get(item_id, null) as ItemState
			if item_state == null or item_state.instance_id != item_id or item_state.cell != coordinates or seen_item_ids.has(item_id):
				return ERR_INVALID_DATA
			seen_item_ids[item_id] = true
	if seen_item_ids.size() != map_state.items.size():
		return ERR_INVALID_DATA
	var restored_items: Array[Item] = []
	for item_id: StringName in map_state.items:
		var item_state: ItemState = map_state.items[item_id]
		var catalog := _catalog_service
		if item_state == null or item_state.instance_id != item_id or catalog == null or not catalog.has_item(item_state.meta_id):
			return ERR_INVALID_DATA
		var item_meta := catalog.get_item(item_state.meta_id)
		if not _state_matches_meta(item_state, item_meta):
			return ERR_INVALID_DATA
		if item_host(item_meta.world_type()) == null:
			return ERR_UNCONFIGURED
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
	for item: Item in restored_items:
		var add_error := add_item(item)
		if add_error != OK:
			_clear_items()
			return add_error
	interaction_revision += 1
	return rebuild_cell_state_projection()

func validate_alignment() -> Error:
	var container := tilemap_container()
	if container == null or container.position != Vector2.ZERO or container.rotation != 0.0 or container.scale != Vector2.ONE:
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
	var configured_item_types: Dictionary[ItemMeta.WorldType, bool] = {}
	for host: Node2D in item_hosts:
		var item_type: ItemMeta.WorldType = item_hosts[host]
		if host == null or not is_ancestor_of(host) or item_type == ItemMeta.WorldType.NONE or configured_item_types.has(item_type):
			return ERR_INVALID_DATA
		configured_item_types[item_type] = true
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

func item_host(item_type: ItemMeta.WorldType) -> Node2D:
	for host: Node2D in item_hosts:
		if item_hosts[host] == item_type:
			return host
	return null

func add_item(item: Item) -> Error:
	if item == null or item.state == null or item.meta == null or item.item_id() == &"":
		return ERR_INVALID_PARAMETER
	if items.has(item.item_id()) or item.get_parent() != null:
		return ERR_ALREADY_EXISTS
	var host := item_host(item.meta.world_type())
	if host == null:
		return ERR_UNCONFIGURED
	host.add_child(item)
	items[item.item_id()] = item
	return OK

func add_item_state(item_state: ItemState) -> Error:
	if _map_state == null or item_state == null or item_state.instance_id == &"":
		return ERR_INVALID_PARAMETER
	if _map_state.items.has(item_state.instance_id) or items.has(item_state.instance_id):
		return ERR_ALREADY_EXISTS
	var catalog := _catalog_service
	var item_meta := catalog.get_item(item_state.meta_id) if catalog != null else null
	if item_meta == null or not _state_matches_meta(item_state, item_meta):
		return ERR_INVALID_PARAMETER
	var cell := get_cell(item_state.cell)
	if cell == null:
		return ERR_DOES_NOT_EXIST
	var add_id_error := cell.add_item_id(item_state.instance_id)
	if add_id_error != OK:
		return add_id_error
	_map_state.items[item_state.instance_id] = item_state
	var item := _create_item(item_state)
	var add_error := add_item(item)
	if add_error != OK:
		_map_state.items.erase(item_state.instance_id)
		var rollback_error := cell.remove_item_id(item_state.instance_id)
		assert(rollback_error == OK)
		return add_error
	interaction_revision += 1
	return OK


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
	item.queue_free()
	interaction_revision += 1
	return OK

func item_count(item_type: ItemMeta.WorldType = ItemMeta.WorldType.NONE) -> int:
	if item_type != ItemMeta.WorldType.NONE:
		var host := item_host(item_type)
		return host.get_child_count() if host != null else 0
	var count := 0
	for host: Node2D in item_hosts:
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

func has_cell_flag(cell: Vector2i, flag: CellState.CellFlag) -> bool:
	var map_cell := get_cell(cell)
	return map_cell != null and map_cell.has_flag(flag)

func is_walkable(cell: Vector2i) -> bool:
	var map_cell := get_cell(cell)
	return map_cell != null and map_cell.is_walkable()


func commit_cell_changes(changed_cells: Array[Vector2i]) -> Error:
	if changed_cells.is_empty():
		return ERR_INVALID_PARAMETER
	for coordinates: Vector2i in changed_cells:
		if not cells.has(coordinates):
			return ERR_DOES_NOT_EXIST
	interaction_revision += 1
	return rebuild_cell_state_projection()


func clear_watered() -> Array[Vector2i]:
	var changed: Array[Vector2i] = []
	for coordinates: Vector2i in cells:
		var cell: MapCell = cells[coordinates]
		if cell.is_watered():
			cell.remove_flag(CellState.CellFlag.WATERED)
			changed.append(coordinates)
	if not changed.is_empty():
		commit_cell_changes(changed)
	return changed


func rebuild_cell_state_projection() -> Error:
	if get_tile_size() == Vector2i.ZERO:
		return ERR_UNCONFIGURED
	_ensure_cell_state_projection()
	if _cell_state_projection == null:
		return ERR_CANT_CREATE
	_cell_state_projection.queue_redraw()
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
				map_cell.add_flag(flag)


func _ensure_cell_state_projection() -> void:
	if is_instance_valid(_cell_state_projection):
		return
	_cell_state_projection = get_node_or_null("CellStateProjection") as Node2D
	if _cell_state_projection == null:
		_cell_state_projection = Node2D.new()
		_cell_state_projection.name = "CellStateProjection"
		_cell_state_projection.z_index = 0
		add_child(_cell_state_projection)
	if not _cell_state_projection.draw.is_connected(_draw_cell_state_projection):
		_cell_state_projection.draw.connect(_draw_cell_state_projection)


func _draw_cell_state_projection() -> void:
	if _cell_state_projection == null:
		return
	var tile_size := Vector2(get_tile_size())
	var inset := Vector2(2, 2)
	for coordinates: Vector2i in cells:
		var cell: MapCell = cells[coordinates]
		if not cell.is_dug():
			continue
		var center := _cell_state_projection.to_local(cell_to_world_center(coordinates))
		var rect := Rect2(center - tile_size * 0.5 + inset, tile_size - inset * 2.0)
		_cell_state_projection.draw_rect(rect, Color("714a32", 0.72), true)
		if cell.is_watered():
			_cell_state_projection.draw_rect(rect.grow(-3.0), Color("4f91a8", 0.58), true)


func _create_item(item_state: ItemState) -> Item:
	var catalog := _catalog_service
	var item_meta := catalog.get_item(item_state.meta_id) if catalog != null else null
	if item_meta == null or not _state_matches_meta(item_state, item_meta):
		return null
	var item: Item
	if item_meta is PlantMeta:
		item = PlantItem.new()
	elif item_meta is HarvestableMeta:
		item = HarvestableItem.new()
	else:
		item = Item.new()
	if item.bind_state(item_state, item_meta) != OK:
		item.free()
		return null
	item.position = cell_to_world_center(item_state.cell)
	return item


func _state_matches_meta(item_state: ItemState, item_meta: ItemMeta) -> bool:
	if item_state == null or item_meta == null:
		return false
	if item_meta is PlantMeta:
		return item_state is PlantState
	if item_meta is HarvestableMeta:
		return item_state is HarvestableState
	return item_state.state_type() == ItemState.StateType.ITEM


func _clear_items() -> void:
	for item: Item in items.values():
		if is_instance_valid(item):
			item.free()
	items.clear()
