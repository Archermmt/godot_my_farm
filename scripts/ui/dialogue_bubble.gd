class_name DialogueBubble
extends PanelContainer

@onready var speaker_label: Label = $Margin/VBox/Speaker
@onready var text_label: Label = $Margin/VBox/Text
@onready var prompt_label: Label = $Margin/VBox/Prompt
var world_target: Node2D = null


func set_content(speaker: String, text: String, complete: bool, confirmation: bool = false) -> void:
	speaker_label.text = speaker
	text_label.text = text
	prompt_label.text = "Enter: Sleep    Esc: Cancel" if confirmation else ("Enter: Continue" if complete else "Enter: Skip")


func set_prompt(speaker: String, text: String = "") -> void:
	speaker_label.text = speaker
	text_label.text = text
	prompt_label.text = "Enter: Interact"


func _process(_delta: float) -> void:
	if not is_instance_valid(world_target):
		visible = false
		return
	visible = true
	var viewport_size: Vector2 = get_viewport_rect().size
	# The target's canvas transform already includes the active Camera2D. Unlike
	# Camera3D, Camera2D has no unproject_position() API.
	var screen_position := world_target.get_global_transform_with_canvas().origin + Vector2(0, -42)
	position = Vector2(
		clampf(screen_position.x - size.x * 0.5, 8.0, viewport_size.x - size.x - 8.0),
		clampf(screen_position.y - size.y, 8.0, viewport_size.y - size.y - 8.0)
	)
