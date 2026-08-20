class_name FarmHouse
extends Node2D

@onready var roof_layer: TileMapLayer = $TileMaps/RoofLayer
var _actor_inside := false
var _interaction_enabled := false


func _ready() -> void:
	$InteriorArea.body_entered.connect(_on_body_entered)
	$InteriorArea.body_exited.connect(_on_body_exited)
	roof_layer.visible = true


func _exit_tree() -> void:
	if _actor_inside:
		EventBus.house_interior_changed.emit(self, null, false)
		_actor_inside = false


func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	if enabled and not _actor_inside:
		roof_layer.visible = true
	if not enabled and _actor_inside:
		roof_layer.visible = true
		EventBus.house_interior_changed.emit(self, null, false)
		_actor_inside = false


func _on_body_entered(body: Node2D) -> void:
	if not _interaction_enabled or not body.is_in_group("player"):
		return
	if _actor_inside:
		return
	_actor_inside = true
	roof_layer.visible = false
	EventBus.house_interior_changed.emit(self, body, true)


func _on_body_exited(body: Node2D) -> void:
	if not _interaction_enabled or not _actor_inside or not body.is_in_group("player"):
		return
	roof_layer.visible = true
	_actor_inside = false
	EventBus.house_interior_changed.emit(self, body, false)
