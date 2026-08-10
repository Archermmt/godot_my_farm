class_name DialogueBubble
extends PanelContainer

@onready var speaker_label: Label = $Margin/VBox/Speaker
@onready var text_label: Label = $Margin/VBox/Text
@onready var prompt_label: Label = $Margin/VBox/Prompt

func _ready() -> void:
	resized.connect(_center_on_marker)
	call_deferred("_center_on_marker")


func set_prompt(interactable_name: String) -> void:
	speaker_label.text = interactable_name
	# The bubble inherits the global UI theme at runtime; explicitly override
	# the speaker color so names remain readable on the dark panel background.
	speaker_label.add_theme_color_override("font_color", Color("f5f5f0"))
	text_label.visible = false
	prompt_label.visible = false
	call_deferred("_center_on_marker")


func _center_on_marker() -> void:
	if get_parent() is Node2D:
		position = -size * 0.5
