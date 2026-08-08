class_name SaveManagerService
extends Node

var _game_state: GameStateService = null
var _time_manager: TimeManagerService = null


func _ready() -> void:
	configure(GameState, TimeManager)


func configure(game_state_service: GameStateService, time_manager_service: TimeManagerService) -> void:
	_game_state = game_state_service
	_time_manager = time_manager_service


func can_snapshot() -> bool:
	return _game_state != null and _game_state.is_initialized() and _time_manager != null


func build_snapshot() -> Dictionary:
	if not can_snapshot():
		return {}
	return {
		"game": _game_state.snapshot(),
		"time": _time_manager.snapshot(),
	}.duplicate(true)


func save_slot(_slot: int = 0) -> Error:
	return ERR_UNAVAILABLE


func load_slot(_slot: int = 0) -> Error:
	return ERR_UNAVAILABLE
