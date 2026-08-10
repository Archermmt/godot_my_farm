extends Node

@export var map_id: StringName = &"farm"
@export var spawn_id: StringName = &"default"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	GameManager.player.map_id = map_id
	GameManager.player.spawn_id = spawn_id
	var main := (load("res://scenes/app/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
