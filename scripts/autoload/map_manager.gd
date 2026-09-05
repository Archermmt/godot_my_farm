class_name MapManagerService
extends Node

const MAP_SCENE_PATHS := {
	&"farm": "res://scenes/maps/farm/farm.tscn",
	&"field": "res://scenes/maps/field/field.tscn",
	&"beach": "res://scenes/maps/beach/beach.tscn",
}
const TRANSITION_LOCK := &"scene_transition"

var config: GameConfig:
	get:
		return DataCatalog.config

var _map_host: Node2D = null
var _actor_host: Node2D = null
var _ui_layer: CanvasLayer = null
var _transition_overlay: CanvasItem = null
var _current_map: BaseMap = null
var _loaded_map_id: StringName = &""
var _current_spawn_id: StringName = &"default"
var _transitioning := false


func validate() -> Error:
	var scene := get_tree().current_scene
	if scene == null:
		return ERR_UNCONFIGURED
	var map_host := scene.get_node_or_null("World/MapHost") as Node2D
	var actor_host := scene.get_node_or_null("World/ActorHost") as Node2D
	var ui_layer := scene.get_node_or_null("UILayer") as CanvasLayer
	var transition_overlay := scene.get_node_or_null("UILayer/TransitionOverlay") as CanvasItem
	if map_host == null or actor_host == null or ui_layer == null or transition_overlay == null:
		return ERR_INVALID_PARAMETER
	_map_host = map_host
	_actor_host = actor_host
	_ui_layer = ui_layer
	_transition_overlay = transition_overlay
	_transition_overlay.modulate = Color(1, 1, 1, 0)
	if _transition_overlay is Control:
		(_transition_overlay as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return OK


func _exit_tree() -> void:
	_map_host = null
	_actor_host = null
	_ui_layer = null
	_transition_overlay = null
	_current_map = null
	_loaded_map_id = &""
	_current_spawn_id = &"default"
	_transitioning = false


func has_registered_hosts() -> bool:
	return (
		is_instance_valid(_map_host)
		and is_instance_valid(_actor_host)
		and is_instance_valid(_ui_layer)
		and is_instance_valid(_transition_overlay)
	)


func actor_host() -> Node2D:
	return _actor_host if is_instance_valid(_actor_host) else null


func current_map() -> BaseMap:
	return _current_map if is_instance_valid(_current_map) else null


func current_map_id() -> StringName:
	return _current_map.map_id if is_instance_valid(_current_map) else &""


func current_spawn_id() -> StringName:
	return _current_spawn_id


func set_loaded_map_id(map_id: StringName) -> void:
	_loaded_map_id = map_id


func apply_loaded_state() -> Error:
	if GameManager.player == null or GameManager.player_state() == null or not has_registered_hosts():
		return ERR_UNCONFIGURED
	var target_id := _loaded_map_id if _loaded_map_id != &"" else current_map_id()
	if target_id == &"":
		target_id = DataCatalog.config.player_map_id
	var target_map := _current_map
	var replacing := target_map == null or target_map.map_id != target_id
	if replacing:
		target_map = _instantiate_map(target_id)
		if target_map == null:
			return ERR_CANT_OPEN
		_map_host.add_child(target_map)
	var error: Error
	if replacing:
		error = _configure_map(target_map, target_id, GameManager.config.player_spawn_id)
	else:
		error = target_map.setup(GameManager.maps.get(target_id, null) as MapState)
	if error != OK:
		if replacing and is_instance_valid(target_map):
			target_map.queue_free()
		return error
	if replacing:
		var old_map := _current_map
		_current_map = target_map
		if old_map != null:
			old_map.queue_free()
	_current_spawn_id = GameManager.config.player_spawn_id
	EventBus.map_changed.emit(target_id)
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
	_current_spawn_id = spawn_id
	EventBus.map_changed.emit(map_id)
	return OK


func is_transitioning() -> bool:
	return _transitioning


func place_player_at_spawn(spawn_id: StringName) -> Error:
	if _current_map == null or GameManager.player == null or GameManager.player.state == null:
		return ERR_UNCONFIGURED
	var spawn := _current_map.spawn_position(spawn_id)
	if not _current_map.cells.has(_current_map.world_to_cell(spawn)):
		return ERR_INVALID_DATA
	GameManager.player.global_position = spawn
	GameManager.player.state.position = spawn
	_current_spawn_id = spawn_id
	return OK


func request_map_change(map_id: StringName, spawn_id: StringName) -> Error:
	if not has_registered_hosts() or _current_map == null or GameManager.player == null:
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
	if GameManager.player.state == null:
		return ERR_UNCONFIGURED
	var state: MapState = GameManager.maps.get(map_id, null) as MapState
	if state == null:
		return ERR_DOES_NOT_EXIST
	var error := map.setup(state, true)
	if error != OK:
		return error
	var spawn := map.spawn_position(spawn_id)
	if not map.cells.has(map.world_to_cell(spawn)):
		return ERR_INVALID_DATA
	return OK


func _perform_map_change(map_id: StringName, spawn_id: StringName) -> void:
	var next_map := _instantiate_map(map_id)
	var error: Error = OK
	if next_map == null:
		error = ERR_CANT_OPEN
	else:
		error = GameManager.player.lock_input(TRANSITION_LOCK)
		if error == OK:
			error = CalendarManager.pause(TRANSITION_LOCK)
	if error != OK:
		if next_map != null:
			next_map.queue_free()
		_finish_failed(map_id, error)
		return

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
	_current_spawn_id = spawn_id
	EventBus.map_changed.emit(map_id)
	await _fade(0.0)
	CalendarManager.resume(TRANSITION_LOCK)
	GameManager.player.unlock_input(TRANSITION_LOCK)
	_transitioning = false


func move_to_farm_wake() -> Error:
	if current_map_id() == &"farm":
		return place_player_at_spawn(&"wake")
	var next_map := _instantiate_map(&"farm")
	if next_map == null:
		return ERR_CANT_OPEN
	_map_host.add_child(next_map)
	await get_tree().process_frame
	var error := _configure_map(next_map, &"farm", &"wake")
	if error != OK:
		next_map.queue_free()
		return error
	var old_map := _current_map
	_current_map = next_map
	if old_map != null:
		old_map.queue_free()
	_current_spawn_id = &"wake"
	EventBus.map_changed.emit(&"farm")
	return OK


func _finish_failed(map_id: StringName, error: Error) -> void:
	CalendarManager.resume(TRANSITION_LOCK)
	if GameManager.player != null:
		GameManager.player.unlock_input(TRANSITION_LOCK)
	_transitioning = false
	EventBus.map_change_failed.emit(map_id, error)


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
