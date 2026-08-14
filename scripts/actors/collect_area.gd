class_name CollectArea
extends Area2D

@export_range(8.0, 160.0, 1.0) var pickup_radius: float = 72.0


func _ready() -> void:
	monitoring = false
	monitorable = false
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = pickup_radius
	collision.shape = shape
	add_child(collision)
