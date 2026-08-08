class_name SceneRouterService
extends Node

var _map_host: Node2D = null
var _actor_host: Node2D = null
var _ui_layer: CanvasLayer = null
var _transition_overlay: CanvasItem = null
var _player: FarmPlayer = null


func register_hosts(
	map_host: Node2D,
	actor_host: Node2D,
	ui_layer: CanvasLayer,
	transition_overlay: CanvasItem
) -> Error:
	if map_host == null or actor_host == null or ui_layer == null or transition_overlay == null:
		return ERR_INVALID_PARAMETER
	_map_host = map_host
	_actor_host = actor_host
	_ui_layer = ui_layer
	_transition_overlay = transition_overlay
	return OK


func unregister_hosts(map_host: Node2D) -> void:
	if map_host != _map_host:
		return
	_map_host = null
	_actor_host = null
	_ui_layer = null
	_transition_overlay = null
	_player = null


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


func request_map_change(_map_id: StringName, _spawn_id: StringName) -> Error:
	return ERR_UNAVAILABLE
