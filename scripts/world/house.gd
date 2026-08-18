class_name FarmHouse
extends Node2D

@export var indoor_camera_zoom := Vector2(1.5, 1.5)

@onready var roof_layer: TileMapLayer = $TileMaps/RoofLayer
var _player_inside: FarmPlayer = null
var _interaction_enabled := false


func _ready() -> void:
	$InteriorArea.body_entered.connect(_on_body_entered)
	$InteriorArea.body_exited.connect(_on_body_exited)
	roof_layer.visible = true


func _exit_tree() -> void:
	if is_instance_valid(_player_inside):
		_player_inside.set_house_interior(false)
	_player_inside = null


func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	if enabled and not is_instance_valid(_player_inside):
		roof_layer.visible = true
	if not enabled and is_instance_valid(_player_inside):
		roof_layer.visible = true
		_player_inside.set_house_interior(false)
		_player_inside = null


func _on_body_entered(body: Node2D) -> void:
	if not _interaction_enabled or not body is FarmPlayer:
		return
	if body == _player_inside:
		return
	_player_inside = body as FarmPlayer
	roof_layer.visible = false
	_player_inside.set_house_interior(true, indoor_camera_zoom)


func _on_body_exited(body: Node2D) -> void:
	if not _interaction_enabled or body != _player_inside:
		return
	roof_layer.visible = true
	_player_inside.set_house_interior(false)
	_player_inside = null
