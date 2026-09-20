class_name CellTool
extends Tool

const PREVIEW_FILL := Color(0.95, 0.75, 0.25, 0.28)
const PREVIEW_BORDER := Color("ffe28a")
const PREVIEW_VALID := Color(0.15, 0.95, 0.3, 0.48)
const PREVIEW_INVALID := Color(1.0, 0.78, 0.12, 0.48)
const FACING_VECTORS := {
	&"up": Vector2i(0, -1), &"down": Vector2i(0, 1), &"left": Vector2i(-1, 0), &"right": Vector2i(1, 0)
}

func _ready() -> void:
	super._ready()
	# Cell tools are runtime inventory objects. Their icon is shown by HeldVisual,
	# never by the hidden tool entity itself.
	if visual != null:
		visual.visible = false

func begin_charge() -> Error:
	var result := super.begin_charge()
	if result == OK and GameManager.player != null:
		global_position = GameManager.player.global_position
	queue_redraw()
	return result


func target_cells(map: BaseMap, player: FarmPlayer) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if map == null or player == null:
		return result
	var origin := map.world_to_cell(player.global_position)
	var typed_meta := meta as CellToolMeta
	var dimensions := typed_meta.level_area(charge_level) if typed_meta != null else Vector2i.ONE
	var forward: Vector2i = FACING_VECTORS.get(player.facing, Vector2i.DOWN)
	var lateral := Vector2i(-forward.y, forward.x)
	var lateral_start := -floori(float(dimensions.y - 1) / 2.0)
	for distance: int in range(1, dimensions.x + 1):
		for lateral_offset: int in range(lateral_start, lateral_start + dimensions.y):
			var cell := origin + forward * distance + lateral * lateral_offset
			if map.has_static_cell(cell) and map.check_cell(cell, _target_condition()):
				result.append(cell)
	return result


func _target_condition() -> CellState.CellCondition:
	return CellState.CellCondition.DIGGABLE


func _use_impl() -> ApplyResult:
	var map := MapManager.current_map()
	var player := GameManager.player
	var targets: Array[Vector2i] = target_cells(map, player)
	var result := ApplyResult.new()
	for coordinates: Vector2i in targets:
		if _apply_cell(map.ensure_cell(coordinates)):
			result.cells[coordinates] = CellState.new()
	if not result.cells.is_empty():
		var changed: Array[Vector2i] = []
		changed.assign(result.cells.keys())
		map.rebuild_layers(changed)
	return result


func update_charge(delta: float) -> void:
	super.update_charge(delta)
	var player := GameManager.player
	if player != null:
		# Runtime tools live under PlayerBackpack; keep the preview in world space.
		global_position = player.global_position
		global_rotation = 0.0
	queue_redraw()


func cancel_charge() -> void:
	super.cancel_charge()
	queue_redraw()


func _draw() -> void:
	if not charging:
		return
	var map := MapManager.current_map()
	var player := GameManager.player
	if map == null or player == null:
		return
	var tile_size := Vector2(map.get_tile_size())
	if tile_size.x <= 0.0 or tile_size.y <= 0.0:
		return
	var usable_count := 0
	for cell: Vector2i in _preview_cells(map, player):
		var center := to_local(map.cell_to_world(cell))
		var rect := Rect2(center - tile_size * 0.5, tile_size)
		var valid := _preview_cell_usable(map, cell, usable_count)
		if valid:
			usable_count += 1
		var preview_color := PREVIEW_VALID if valid else PREVIEW_INVALID
		draw_rect(rect, preview_color, true)
		draw_rect(rect, preview_color.lightened(0.25), false, 2.0)

func _preview_cell_usable(map: BaseMap, cell: Vector2i, usable_count: int) -> bool:
	return map.has_static_cell(cell) and map.check_cell(cell, _target_condition())

func _preview_cells(map: BaseMap, player: FarmPlayer) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var origin := map.world_to_cell(player.global_position)
	var dimensions := (meta as CellToolMeta).level_area(charge_level)
	var forward: Vector2i = FACING_VECTORS.get(player.facing, Vector2i.DOWN)
	var lateral := Vector2i(-forward.y, forward.x)
	var lateral_start := -floori(float(dimensions.y - 1) / 2.0)
	for distance in range(1, dimensions.x + 1):
		for lateral_offset in range(lateral_start, lateral_start + dimensions.y):
			result.append(origin + forward * distance + lateral * lateral_offset)
	return result


func _apply_cell(_cell: MapCell) -> bool:
	return false
