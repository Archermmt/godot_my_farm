class_name TimeManagerService
extends Node

var calendar: CalendarState = CalendarState.new()
var time_scale: float = 60.0
var _running: bool = false
var _pause_reasons: Dictionary[StringName, bool] = {}


func start() -> void:
	_running = true


func stop() -> void:
	_running = false


func is_running() -> bool:
	return _running


func pause(reason: StringName) -> Error:
	if reason == &"":
		return ERR_INVALID_PARAMETER
	_pause_reasons[reason] = true
	return OK


func resume(reason: StringName) -> Error:
	if reason == &"":
		return ERR_INVALID_PARAMETER
	if not _pause_reasons.erase(reason):
		return ERR_DOES_NOT_EXIST
	return OK


func is_paused() -> bool:
	return not _pause_reasons.is_empty()


func can_advance() -> bool:
	return _running and not is_paused()


func pause_reasons() -> Array[StringName]:
	var reasons: Array[StringName] = []
	reasons.assign(_pause_reasons.keys())
	reasons.sort()
	return reasons


func reset() -> void:
	stop()
	_pause_reasons.clear()
	calendar = CalendarState.new()


func snapshot() -> Dictionary:
	return {
		"calendar": calendar.to_dict(),
		"time_scale": time_scale,
		"running": _running,
		"pause_reasons": SerializationUtil.string_name_array_to_strings(pause_reasons()),
	}.duplicate(true)
