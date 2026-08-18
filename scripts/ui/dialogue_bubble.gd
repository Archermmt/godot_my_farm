class_name DialogueBubble
extends PanelContainer

@onready var speaker_label: Label = $Margin/VBox/Speaker
@onready var text_label: Label = $Margin/VBox/Text
@onready var prompt_label: Label = $Margin/VBox/Prompt
var world_target: Node2D = null
var camera: Camera2D = null


func set_content(speaker: String, text: String, complete: bool, confirmation: bool = false) -> void:
	speaker_label.text = speaker
	text_label.text = text
	prompt_label.text = "Enter: Sleep    Esc: Cancel" if confirmation else ("Enter: Continue" if complete else "Enter: Skip")


func _process(_delta: float) -> void:
	if not is_instance_valid(world_target) or not is_instance_valid(camera):
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var screen_position: Vector2 = camera.unproject_position(world_target.global_position) + Vector2(0, -42)
	position = Vector2(
		clampf(screen_position.x - size.x * 0.5, 8.0, viewport_size.x - size.x - 8.0),
		clampf(screen_position.y - size.y, 8.0, viewport_size.y - size.y - 8.0)
	)
