class_name InteractionCursor
extends Node2D

enum InteractionState {
	IDLE,
	CHARGING,
	COMMITTED,
	CANCELLED,
}

const CHARGE_THRESHOLDS := [0.0, 0.25, 0.5, 0.75, 1.0]
const FACING_VECTORS := {
	&"up": Vector2i(0, -1),
	&"down": Vector2i(0, 1),
	&"left": Vector2i(-1, 0),
	&"right": Vector2i(1, 0),
}

var state: InteractionState = InteractionState.IDLE
var charge_level: int = 0
var charge_elapsed: float = 0.0
var preview: Array[CellState] = []
var player_state: PlayerState = null
var last_tool_outcome: ToolOutcome = null
var last_seed_outcome: SeedOutcome = null

var _map: BaseMap = null
var _meta: ItemMeta = null
var _map_revision: int = 0
var _commit_emitted := false
var _event_bus_service: EventBusService = null


func configure(event_bus_service: EventBusService) -> void:
	_event_bus_service = event_bus_service


func begin(next_player_state: PlayerState, map: BaseMap, meta: ItemMeta) -> Error:
	if state == InteractionState.CHARGING:
		return ERR_BUSY
	if next_player_state == null or map == null or meta == null:
		return ERR_INVALID_PARAMETER
	if not meta is ToolMeta and not meta is SeedMeta:
		return ERR_UNAVAILABLE
	player_state = next_player_state
	_map = map
	_meta = meta
	_map_revision = map.interaction_revision
	charge_level = 0
	charge_elapsed = 0.0
	_commit_emitted = false
	last_tool_outcome = null
	last_seed_outcome = null
	state = InteractionState.CHARGING
	_refresh_preview()
	return OK


func update(delta: float) -> void:
	if state != InteractionState.CHARGING:
		return
	charge_elapsed += maxf(0.0, delta)
	var next_level := _level_for_elapsed()
	if next_level == charge_level:
		return
	charge_level = next_level
	_refresh_preview()


func move_origin(next_cell: Vector2i) -> Error:
	if state != InteractionState.CHARGING or player_state == null or _map == null:
		return ERR_UNAVAILABLE
	if not _map.contains_cell(next_cell):
		return ERR_INVALID_PARAMETER
	if next_cell == player_state.cell:
		return OK
	player_state.cell = next_cell
	_refresh_preview()
	return OK


func release() -> Error:
	if state != InteractionState.CHARGING:
		return ERR_UNAVAILABLE
	if _map == null or player_state == null or _map.interaction_revision != _map_revision:
		cancel()
		return ERR_INVALID_DATA
	state = InteractionState.COMMITTED
	var valid_cells: Array[Vector2i] = []
	if _meta is ToolMeta:
		var target_cells: Array[Vector2i] = []
		for cell_state: CellState in preview:
			target_cells.append(cell_state.cell)
		last_tool_outcome = Tool.perform(_meta as ToolMeta, _map, target_cells, player_state.stamina, player_state.cell)
		if last_tool_outcome.error != OK:
			var tool_error := last_tool_outcome.error
			_clear_to_idle()
			return tool_error
		valid_cells = last_tool_outcome.effect_cells.duplicate()
	elif _meta is SeedMeta:
		var seed_cells: Array[Vector2i] = []
		for cell_state: CellState in preview:
			if (cell_state.interaction_flags & CellState.InteractionFlag.VALID) != 0:
				seed_cells.append(cell_state.cell)
		var stack := player_state.active_stack()
		last_seed_outcome = Seed.perform(_meta as SeedMeta, _map.catalog(), _map, seed_cells, GameManager.calendar.day, stack.amount)
		if last_seed_outcome.error != OK:
			var seed_error := last_seed_outcome.error
			_clear_to_idle()
			return seed_error
		valid_cells = last_seed_outcome.effect_cells.duplicate()
	else:
		for cell_state: CellState in preview:
			if (cell_state.interaction_flags & CellState.InteractionFlag.VALID) != 0:
				valid_cells.append(cell_state.cell)
	if valid_cells.is_empty():
		cancel()
		return ERR_UNAVAILABLE
	if not _commit_emitted:
		_commit_emitted = true
		if _event_bus_service != null:
			_event_bus_service.interaction_committed.emit(_action_id(), valid_cells)
	_clear_to_idle()
	return OK


func cancel() -> void:
	if state == InteractionState.IDLE:
		return
	state = InteractionState.CANCELLED
	_clear_to_idle()


func is_charging() -> bool:
	return state == InteractionState.CHARGING


func _refresh_preview() -> void:
	preview = _build_preview()
	queue_redraw()


func _build_preview() -> Array[CellState]:
	var result: Array[CellState] = []
	if player_state == null or _map == null or _meta == null:
		return result
	var stack := player_state.active_stack()
	if stack == null or stack.is_empty() or player_state.stamina <= 0:
		return result
	var dimensions := _dimensions(charge_level)
	var target_cells := _target_cells(player_state.cell, player_state.facing, dimensions.x, dimensions.y)
	for index: int in target_cells.size():
		var cell: Vector2i = target_cells[index]
		if not _map.contains_cell(cell):
			continue
		var map_cell := _map.get_cell(cell)
		var source_state := map_cell.cell_state()
		var preview_state := CellState.new()
		preview_state.cell = source_state.cell
		preview_state.flags = source_state.flags
		preview_state.item_ids = source_state.item_ids.duplicate()
		var has_seed := not _meta is SeedMeta or index < stack.amount
		preview_state.interaction_flags = CellState.InteractionFlag.VALID if has_seed and _cell_accepts(map_cell) else CellState.InteractionFlag.INVALID
		if not source_state.item_ids.is_empty():
			preview_state.interaction_flags |= CellState.InteractionFlag.ENTITY
		result.append(preview_state)
	return result


func _level_for_elapsed() -> int:
	var next_level := 0
	for index: int in range(CHARGE_THRESHOLDS.size()):
		if charge_elapsed >= CHARGE_THRESHOLDS[index]:
			next_level = index
	return mini(next_level, _max_charge_level())


func _max_charge_level() -> int:
	return maxi(0, _charge_levels().size() - 1)


func _dimensions(level: int) -> Vector2i:
	var levels := _charge_levels()
	if levels.is_empty():
		return Vector2i.ONE
	var configured := levels[clampi(level, 0, levels.size() - 1)]
	return Vector2i(maxi(1, configured.x), maxi(1, configured.y))


func _charge_levels() -> Array[Vector2i]:
	if _meta is ToolMeta:
		return (_meta as ToolMeta).charge_levels
	if _meta is SeedMeta:
		return (_meta as SeedMeta).charge_levels
	return []


func _target_cells(origin: Vector2i, facing: StringName, length: int, width: int) -> Array[Vector2i]:
	var forward: Vector2i = FACING_VECTORS.get(facing, Vector2i.DOWN)
	var lateral := Vector2i(-forward.y, forward.x)
	var result: Array[Vector2i] = []
	var lateral_start := -floori(float(width - 1) / 2.0)
	for distance: int in range(1, length + 1):
		for lateral_offset: int in range(lateral_start, lateral_start + width):
			result.append(origin + forward * distance + lateral * lateral_offset)
	return result


func _cell_accepts(cell: MapCell) -> bool:
	if cell == null:
		return false
	if _meta is SeedMeta:
		return _map.check_cell(cell.coordinates, BaseMap.CellCondition.PLANTABLE)
	if not _meta is ToolMeta:
		return false
	var tool_meta := _meta as ToolMeta
	if Tool.targets_cells(tool_meta):
		return Tool.cell_rejection_reason(tool_meta, cell) == &""
	if tool_meta.tool_kind == ToolMeta.ToolKind.NONE:
		return cell.has_occupant()
	return Tool.item_rejection_reason(tool_meta, _map, cell.coordinates) == &""


func _action_id() -> StringName:
	if _meta is SeedMeta:
		return &"seed"
	if _meta is ToolMeta:
		return &"grid_tool" if Tool.targets_cells(_meta as ToolMeta) else &"harvest_tool"
	return &"use"


func _clear_to_idle() -> void:
	state = InteractionState.IDLE
	charge_level = 0
	charge_elapsed = 0.0
	preview.clear()
	player_state = null
	_map = null
	_meta = null
	_commit_emitted = false
	queue_redraw()
func _draw() -> void:
	if _map == null:
		return
	var tile_size := Vector2(_map.get_tile_size())
	for cell_state: CellState in preview:
		var center := to_local(_map.cell_to_world_center(cell_state.cell))
		var rect := Rect2(center - tile_size * 0.5, tile_size)
		var is_valid := (cell_state.interaction_flags & CellState.InteractionFlag.VALID) != 0
		draw_rect(rect, Color("78d6a3", 0.38) if is_valid else Color("e05a63", 0.32), true)
		draw_rect(rect, Color("b8f2cf") if is_valid else Color("ff9ca2"), false, 2.0)
		if (cell_state.interaction_flags & CellState.InteractionFlag.ENTITY) != 0:
			draw_circle(center, minf(tile_size.x, tile_size.y) * 0.18, Color("ffe28a"))
