class_name BurstParticles
extends Node2D

@export_range(0.1, 5.0, 0.05) var cleanup_delay: float = 1.2

@onready var emitter_template: CPUParticles2D = $EmitterTemplate


func configure(_event_id: StringName, world_position: Vector2) -> void:
	if emitter_template == null:
		queue_free()
		return
	emitter_template.position = to_local(world_position)
	emitter_template.emitting = true
	emitter_template.restart()
	var timer := get_tree().create_timer(cleanup_delay)
	timer.timeout.connect(queue_free)
