class_name BurstParticles
extends Node2D

@export_range(1, 32, 1) var max_emitters: int = 12
@export_range(0.1, 5.0, 0.05) var cleanup_delay: float = 1.2

@onready var emitter_template: CPUParticles2D = $EmitterTemplate


func configure(_event_id: StringName, cells: Array[Vector2i], map: BaseMap) -> void:
	if map == null or cells.is_empty() or emitter_template == null:
		queue_free()
		return
	var emitter_count := mini(cells.size(), max_emitters)
	for index: int in emitter_count:
		var emitter := emitter_template if index == 0 else emitter_template.duplicate() as CPUParticles2D
		if index > 0:
			add_child(emitter)
		emitter.position = to_local(map.cell_to_world_center(cells[index]))
		emitter.emitting = true
		emitter.restart()
	var timer := get_tree().create_timer(cleanup_delay)
	timer.timeout.connect(queue_free)
