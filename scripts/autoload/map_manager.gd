class_name MapManagerService
extends Node

const MAP_SCENE_PATHS := {
	&"farm": "res://scenes/maps/farm/farm.tscn",
	&"field": "res://scenes/maps/field/field.tscn",
	&"beach": "res://scenes/maps/beach/beach.tscn",
}
const TRANSITION_LOCK := &"scene_transition"
const DAY_TRANSITION_LOCK := &"day_transition"
const DEFAULT_CONFIG_PATH := "res://data/game_config.tres"
const NPC_SCENE := preload("res://scenes/actors/npcs/npc.tscn")

var config: GameConfig = load(DEFAULT_CONFIG_PATH) as GameConfig

var _map_host: Node2D = null
var _actor_host: Node2D = null
var _ui_layer: CanvasLayer = null
var _transition_overlay: CanvasItem = null
var _day_transition_overlay: ColorRect = null
var _player: FarmPlayer = null
var _current_map: BaseMap = null
var _npc_actors: Dictionary[StringName, FarmNpc] = {}
var _transitioning := false


func _ready() -> void:
	if not EventBus.time_advanced.is_connected(_on_time_advanced):
		EventBus.time_advanced.connect(_on_time_advanced)
	if not EventBus.npc_states_changed.is_connected(_on_npc_states_changed):
		EventBus.npc_states_changed.connect(_on_npc_states_changed)


func register_hosts(
	map_host: Node2D,
	actor_host: Node2D,
	ui_layer: CanvasLayer,
	transition_overlay: CanvasItem,
	day_transition_overlay: ColorRect = null
) -> Error:
	if map_host == null or actor_host == null or ui_layer == null or transition_overlay == null:
		return ERR_INVALID_PARAMETER
	_map_host = map_host
	_actor_host = actor_host
	_ui_layer = ui_layer
	_transition_overlay = transition_overlay
	_day_transition_overlay = day_transition_overlay
	_transition_overlay.modulate = Color(1, 1, 1, 0)
	if _transition_overlay is Control:
		(_transition_overlay as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return OK


func unregister_hosts(map_host: Node2D) -> void:
	if map_host != _map_host:
		return
	_map_host = null
	_actor_host = null
	_ui_layer = null
	_transition_overlay = null
	_day_transition_overlay = null
	_player = null
	_current_map = null
	_clear_npc_actors()
	_transitioning = false


func has_registered_hosts() -> bool:
	return (
		is_instance_valid(_map_host)
		and is_instance_valid(_actor_host)
		and is_instance_valid(_ui_layer)
		and is_instance_valid(_transition_overlay)
	)


func register_player(player: FarmPlayer) -> Error:
	if player == null:
		return ERR_INVALID_PARAMETER
	if _player != null and _player != player and is_instance_valid(_player):
		return ERR_ALREADY_IN_USE
	_player = player
	return OK


func registered_player() -> FarmPlayer:
	return _player if is_instance_valid(_player) else null


func current_map() -> BaseMap:
	return _current_map if is_instance_valid(_current_map) else null


func current_map_id() -> StringName:
	return _current_map.map_id if is_instance_valid(_current_map) else &""


func apply_loaded_state() -> Error:
	if _player == null or GameManager.player == null or not has_registered_hosts():
		return ERR_UNCONFIGURED
	var target_id := GameManager.player.map_id
	var target_map := _current_map
	var replacing := target_map == null or target_map.map_id != target_id
	if replacing:
		target_map = _instantiate_map(target_id)
		if target_map == null:
			return ERR_CANT_OPEN
		_map_host.add_child(target_map)
	var error: Error
	if replacing:
		error = _configure_map(target_map, target_id, GameManager.player.spawn_id)
	else:
		error = target_map.configure_state(
			GameManager.maps.get(target_id, null) as MapState,
			GameManager.world_seed,
			false,
			_player.trace_delay_for(&"generate")
		)
	if error != OK:
		if replacing and is_instance_valid(target_map):
			target_map.queue_free()
		return error
	var spawn_id := GameManager.player.spawn_id
	var position := target_map.spawn_position(spawn_id)
	if not target_map.map_bounds_world().has_point(position):
		position = target_map.cell_to_world_center(GameManager.player.cell)
	_player.global_position = position
	_player.setup(GameManager.player)
	if replacing:
		var old_map := _current_map
		_current_map = target_map
		_set_house_interaction(target_map, true)
		if old_map != null:
			_set_house_interaction(old_map, false)
			old_map.queue_free()
	_sync_npc_actors()
	EventBus.map_changed.emit(target_id)
	return OK


func is_transitioning() -> bool:
	return _transitioning


func npc_actor_count() -> int:
	return _npc_actors.size()


func can_run_day_transition() -> bool:
	return (
		has_registered_hosts()
		and is_instance_valid(_current_map)
		and is_instance_valid(_player)
		and is_instance_valid(_day_transition_overlay)
		and _day_transition_overlay.material is ShaderMaterial
		and not _transitioning
	)


func request_day_transition() -> Error:
	if not can_run_day_transition():
		return ERR_BUSY if _transitioning else ERR_UNCONFIGURED
	_transitioning = true
	call_deferred("_perform_day_transition")
	return OK


func place_player_at_spawn(spawn_id: StringName) -> Error:
	if _current_map == null or _player == null or _player.state == null:
		return ERR_UNCONFIGURED
	var spawn := _current_map.spawn_position(spawn_id)
	if not _current_map.map_bounds_world().has_point(spawn):
		return ERR_INVALID_DATA
	_player.global_position = spawn
	_player.state.map_id = _current_map.map_id
	_player.state.spawn_id = spawn_id
	_player.state.cell = _current_map.world_to_cell(spawn)
	return OK


func load_initial_map(map_id: StringName, spawn_id: StringName) -> Error:
	if not has_registered_hosts() or _current_map != null:
		return ERR_ALREADY_IN_USE
	var map := _instantiate_map(map_id)
	if map == null:
		return ERR_CANT_OPEN
	_map_host.add_child(map)
	await get_tree().process_frame
	var error := _configure_map(map, map_id, spawn_id)
	if error != OK:
		map.queue_free()
		return error
	_current_map = map
	_set_house_interaction(map, true)
	_sync_npc_actors()
	EventBus.map_changed.emit(map_id)
	return OK


func request_map_change(map_id: StringName, spawn_id: StringName) -> Error:
	if not has_registered_hosts() or _current_map == null or _player == null:
		return ERR_UNCONFIGURED
	if _transitioning:
		return ERR_BUSY
	if map_id == current_map_id():
		return ERR_ALREADY_IN_USE
	if not MAP_SCENE_PATHS.has(map_id):
		return ERR_DOES_NOT_EXIST
	_transitioning = true
	call_deferred("_perform_map_change", map_id, spawn_id)
	return OK


func _instantiate_map(map_id: StringName) -> BaseMap:
	var path: String = str(MAP_SCENE_PATHS.get(map_id, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	return packed.instantiate() as BaseMap


func _configure_map(map: BaseMap, map_id: StringName, spawn_id: StringName) -> Error:
	if map == null or map.map_id != map_id:
		return ERR_INVALID_DATA
	if _player.state == null:
		return ERR_UNCONFIGURED
	var state: MapState = GameManager.maps.get(map_id, null) as MapState
	if state == null:
		return ERR_DOES_NOT_EXIST
	var error := map.validate_alignment()
	if error != OK:
		return error
	error = map.configure_state(state, GameManager.world_seed, true, _player.trace_delay_for(&"generate"))
	if error != OK:
		return error
	var spawn := map.spawn_position(spawn_id)
	if not map.map_bounds_world().has_point(spawn):
		return ERR_INVALID_DATA
	_player.global_position = spawn
	var world_bounds := map.map_bounds_world()
	_player.set_camera_limits(Rect2i(world_bounds.position, world_bounds.size))
	_player.state.map_id = map_id
	_player.state.spawn_id = spawn_id
	_player.state.cell = map.world_to_cell(spawn)
	return OK


func _perform_map_change(map_id: StringName, spawn_id: StringName) -> void:
	var next_map := _instantiate_map(map_id)
	var error: Error = OK
	if next_map == null:
		error = ERR_CANT_OPEN
	else:
		error = _player.lock_input(TRANSITION_LOCK)
		if error == OK:
			error = GameManager.pause(TRANSITION_LOCK)
	if error != OK:
		if next_map != null:
			next_map.queue_free()
		_finish_failed(map_id, error)
		return

	EventBus.map_will_change.emit(current_map_id(), map_id)
	await _fade(1.0)
	_map_host.add_child(next_map)
	await get_tree().process_frame
	error = _configure_map(next_map, map_id, spawn_id)
	if error != OK:
		next_map.queue_free()
		await _fade(0.0)
		_finish_failed(map_id, error)
		return

	var old_map := _current_map
	_current_map = next_map
	_set_house_interaction(next_map, true)
	if old_map != null:
		_set_house_interaction(old_map, false)
		old_map.queue_free()
	_sync_npc_actors()
	EventBus.map_changed.emit(map_id)
	await _fade(0.0)
	GameManager.resume(TRANSITION_LOCK)
	_player.unlock_input(TRANSITION_LOCK)
	_transitioning = false


func _perform_day_transition() -> void:
	var error := _player.lock_input(DAY_TRANSITION_LOCK)
	if error == OK:
		error = GameManager.pause(DAY_TRANSITION_LOCK)
	if error != OK:
		_finish_day_transition(error)
		return
	await _iris_transition(true)
	error = await _prepare_day_start()
	if error == OK:
		error = GameManager.complete_day()
	if error == OK:
		await get_tree().process_frame
		await get_tree().physics_frame
	else:
		GameManager.cancel_end_day()
	await _iris_transition(false)
	_finish_day_transition(error)


func _prepare_day_start() -> Error:
	if current_map_id() == &"farm":
		return place_player_at_spawn(&"wake")
	var next_map := _instantiate_map(&"farm")
	if next_map == null:
		return ERR_CANT_OPEN
	EventBus.map_will_change.emit(current_map_id(), &"farm")
	_map_host.add_child(next_map)
	await get_tree().process_frame
	var error := _configure_map(next_map, &"farm", &"wake")
	if error != OK:
		next_map.queue_free()
		return error
	var old_map := _current_map
	_current_map = next_map
	_set_house_interaction(next_map, true)
	if old_map != null:
		_set_house_interaction(old_map, false)
		old_map.queue_free()
	_sync_npc_actors()
	EventBus.map_changed.emit(&"farm")
	return OK


func _iris_transition(closing: bool) -> void:
	if not is_instance_valid(_day_transition_overlay):
		return
	var material := _day_transition_overlay.material as ShaderMaterial
	if material == null:
		return
	var overlay_size := _day_transition_overlay.size
	if overlay_size.x <= 0.0 or overlay_size.y <= 0.0:
		overlay_size = _day_transition_overlay.get_viewport_rect().size
	var screen_position := _player.get_global_transform_with_canvas().origin
	var normalized_center := Vector2(
		clampf(screen_position.x / maxf(overlay_size.x, 1.0), 0.0, 1.0),
		clampf(screen_position.y / maxf(overlay_size.y, 1.0), 0.0, 1.0)
	)
	var softness := 3.0 / maxf(overlay_size.y, 1.0)
	var maximum_radius := _iris_maximum_radius(screen_position, overlay_size) + softness * 2.0
	var closed_radius := -softness * 2.0
	var from_radius := maximum_radius if closing else closed_radius
	var to_radius := closed_radius if closing else maximum_radius
	material.set_shader_parameter(&"center", normalized_center)
	material.set_shader_parameter(&"softness", softness)
	material.set_shader_parameter(&"radius", from_radius)
	_day_transition_overlay.visible = true
	_day_transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	if config.day_transition_duration > 0.0:
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.tween_method(
			func(value: float) -> void: material.set_shader_parameter(&"radius", value),
			from_radius,
			to_radius,
			config.day_transition_duration
		)
		await tween.finished
	else:
		material.set_shader_parameter(&"radius", to_radius)
	if not closing:
		_day_transition_overlay.visible = false
		_day_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _iris_maximum_radius(center: Vector2, overlay_size: Vector2) -> float:
	var height := maxf(overlay_size.y, 1.0)
	var result := 0.0
	for corner: Vector2 in [Vector2.ZERO, Vector2(overlay_size.x, 0.0), overlay_size, Vector2(0.0, overlay_size.y)]:
		var pixel_offset := corner - center
		result = maxf(result, Vector2(pixel_offset.x / height, pixel_offset.y / height).length())
	return result


func _finish_day_transition(error: Error) -> void:
	GameManager.resume(DAY_TRANSITION_LOCK)
	if _player != null:
		_player.unlock_input(DAY_TRANSITION_LOCK)
	_transitioning = false
	if error != OK:
		GameManager.cancel_end_day()
		push_error("[MapManager] day transition failed: %s" % error_string(error))


func _finish_failed(map_id: StringName, error: Error) -> void:
	GameManager.resume(TRANSITION_LOCK)
	if _player != null:
		_player.unlock_input(TRANSITION_LOCK)
	_transitioning = false
	EventBus.map_change_failed.emit(map_id, error)


func _set_house_interaction(map: BaseMap, enabled: bool) -> void:
	if map == null:
		return
	for child: Node in map.find_children("*", "FarmHouse", true, false):
		(child as FarmHouse).set_interaction_enabled(enabled)


func _sync_npc_actors() -> void:
	if not is_instance_valid(_actor_host) or not is_instance_valid(_current_map):
		return
	for npc_id: StringName in _npc_actors.keys():
		var npc_state := GameManager.get_npc(npc_id)
		if npc_state == null or npc_state.map_id != current_map_id():
			var actor := _npc_actors[npc_id]
			_npc_actors.erase(npc_id)
			if is_instance_valid(actor):
				actor.queue_free()
	for npc_state: NpcState in GameManager.npcs.values():
		if npc_state.map_id != current_map_id():
			continue
		var existing := _npc_actors.get(npc_state.npc_id, null) as FarmNpc
		if existing != null and is_instance_valid(existing):
			existing.refresh_target()
			continue
		var actor := NPC_SCENE.instantiate() as FarmNpc
		if actor == null:
			continue
		_actor_host.add_child(actor)
		if actor.bind(npc_state, _current_map) != OK:
			actor.queue_free()
			continue
		actor.name = String(npc_state.npc_id)
		_npc_actors[npc_state.npc_id] = actor


func _clear_npc_actors() -> void:
	for actor: FarmNpc in _npc_actors.values():
		if is_instance_valid(actor):
			actor.queue_free()
	_npc_actors.clear()


func _on_time_advanced(_unit: int, _before: Dictionary, _delta: int) -> void:
	_sync_npc_actors()


func _on_npc_states_changed() -> void:
	_sync_npc_actors()


func _fade(alpha: float) -> void:
	if _transition_overlay == null:
		return
	if _transition_overlay is Control and alpha > 0.0:
		(_transition_overlay as Control).mouse_filter = Control.MOUSE_FILTER_STOP
	if config.transition_duration <= 0.0:
		_transition_overlay.modulate.a = alpha
		if _transition_overlay is Control and alpha <= 0.0:
			(_transition_overlay as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	var tween := create_tween()
	tween.tween_property(_transition_overlay, "modulate:a", alpha, config.transition_duration)
	await tween.finished
	if _transition_overlay is Control and alpha <= 0.0:
		(_transition_overlay as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
