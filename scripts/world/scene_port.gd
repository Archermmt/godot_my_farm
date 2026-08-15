class_name ScenePort
extends Area2D

@export var target_map_id: StringName = &"farm"
@export var target_spawn_id: StringName = &"default"
@export var trigger_once: bool = true
var _submitted := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if not EventBus.map_change_failed.is_connected(_on_map_change_failed):
		EventBus.map_change_failed.connect(_on_map_change_failed)

func _on_body_entered(body: Node2D) -> void:
	if not body is FarmPlayer or (trigger_once and _submitted):
		return
	var error := SceneManager.request_map_change(target_map_id, target_spawn_id)
	if error == OK:
		_submitted = true

func _on_map_change_failed(_map_id: StringName, _error: Error) -> void:
	_submitted = false
