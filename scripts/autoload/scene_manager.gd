class_name SceneManagerService
extends Node

const MAP_SCENE_PATHS := {
	&"farm": "res://scenes/maps/farm/farm.tscn",
	&"field": "res://scenes/maps/field/field.tscn",
	&"cabin": "res://scenes/maps/cabin/cabin.tscn",
}
const TRANSITION_LOCK := &"scene_transition"

var _map_host: Node2D = null
var _actor_host: Node2D = null
var _ui_layer: CanvasLayer = null
var _transition_overlay: CanvasItem = null
var _player: FarmPlayer = null
var _current_map: BaseMap = null
var _transitioning := false
var transition_duration := 0.12

func register_hosts(map_host: Node2D, actor_host: Node2D, ui_layer: CanvasLayer, transition_overlay: CanvasItem) -> Error:
	if map_host == null or actor_host == null or ui_layer == null or transition_overlay == null:
		return ERR_INVALID_PARAMETER
	_map_host = map_host
	_actor_host = actor_host
	_ui_layer = ui_layer
	_transition_overlay = transition_overlay
	_transition_overlay.modulate = Color(1, 1, 1, 0)
	return OK

func unregister_hosts(map_host: Node2D) -> void:
	if map_host != _map_host:
		return
	_map_host = null
	_actor_host = null
	_ui_layer = null
	_transition_overlay = null
	_player = null
	_current_map = null
	_transitioning = false

func has_registered_hosts() -> bool:
	return is_instance_valid(_map_host) and is_instance_valid(_actor_host) and is_instance_valid(_ui_layer) and is_instance_valid(_transition_overlay)

func register_player(player: FarmPlayer) -> Error:
	if player == null:
		return ERR_INVALID_PARAMETER
	if _player != null and _player != player and is_instance_valid(_player):
		return ERR_ALREADY_IN_USE
	_player = player
	return OK

func registered_player() -> FarmPlayer:
	return _player if is_instance_valid(_player) else null

func registered_map_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(MAP_SCENE_PATHS.keys())
	ids.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	return ids

func current_map() -> BaseMap:
	return _current_map if is_instance_valid(_current_map) else null

func current_map_id() -> StringName:
	return _current_map.map_id if is_instance_valid(_current_map) else &""

func is_transitioning() -> bool:
	return _transitioning

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
	_event_bus().map_changed.emit(map_id)
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
	var game_manager := _game_manager()
	if game_manager == null or _player.state == null:
		return ERR_UNCONFIGURED
	var state: MapState = game_manager.maps.get(map_id, null) as MapState
	if state == null:
		return ERR_DOES_NOT_EXIST
	var error := map.validate_alignment()
	if error != OK:
		return error
	error = map.configure_state(state)
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
			error = _game_manager().pause(TRANSITION_LOCK)
	if error != OK:
		if next_map != null:
			next_map.queue_free()
		_finish_failed(map_id, error)
		return

	_event_bus().map_will_change.emit(current_map_id(), map_id)
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
	if old_map != null:
		old_map.queue_free()
	_event_bus().map_changed.emit(map_id)
	await _fade(0.0)
	_game_manager().resume(TRANSITION_LOCK)
	_player.unlock_input(TRANSITION_LOCK)
	_transitioning = false

func _finish_failed(map_id: StringName, error: Error) -> void:
	_game_manager().resume(TRANSITION_LOCK)
	if _player != null:
		_player.unlock_input(TRANSITION_LOCK)
	_transitioning = false
	_event_bus().map_change_failed.emit(map_id, error)

func _event_bus() -> EventBusService:
	return get_tree().root.get_node_or_null("EventBus") as EventBusService

func _game_manager() -> GameManagerService:
	return get_tree().root.get_node_or_null("GameManager") as GameManagerService

func _fade(alpha: float) -> void:
	if _transition_overlay == null:
		return
	if transition_duration <= 0.0:
		_transition_overlay.modulate.a = alpha
		return
	var tween := create_tween()
	tween.tween_property(_transition_overlay, "modulate:a", alpha, transition_duration)
	await tween.finished
