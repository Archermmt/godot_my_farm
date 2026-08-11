class_name ScenePort
extends Area2D

@export var target_map_id: StringName = &"farm"
@export var target_spawn_id: StringName = &"default"
@export var trigger_once: bool = true
var _submitted := false
var _event_bus_service: EventBusService = null
var _scene_manager_service: SceneManagerService = null

func _ready() -> void:
	_event_bus_service = EventBus
	_scene_manager_service = SceneManager
	body_entered.connect(_on_body_entered)
	if _event_bus_service != null and not _event_bus_service.map_change_failed.is_connected(_on_map_change_failed):
		_event_bus_service.map_change_failed.connect(_on_map_change_failed)

func _on_body_entered(body: Node2D) -> void:
	if not body is FarmPlayer or (trigger_once and _submitted):
		return
	if _scene_manager_service == null:
		return
	var error := _scene_manager_service.request_map_change(target_map_id, target_spawn_id)
	if error == OK:
		_submitted = true

func _on_map_change_failed(_map_id: StringName, _error: Error) -> void:
	_submitted = false
