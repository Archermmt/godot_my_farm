class_name BurstParticles
extends Node2D

@export_range(0.1, 5.0, 0.05) var cleanup_delay: float = 1.2

@onready var emitter_template: CPUParticles2D = $EmitterTemplate


func play(_event_id: StringName, positions: Array[Vector2]) -> void:
	if emitter_template == null:
		queue_free()
		return
	var world_position := positions[0] if not positions.is_empty() else Vector2.ZERO
	emitter_template.position = to_local(world_position)
	emitter_template.emitting = true
	emitter_template.restart()
	var timer := get_tree().create_timer(cleanup_delay)
	timer.timeout.connect(queue_free)
