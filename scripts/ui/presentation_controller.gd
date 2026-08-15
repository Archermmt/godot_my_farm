class_name PresentationController
extends Control

var _toast_tween: Tween = null

@onready var toast: ColorRect = $Toast
@onready var toast_label: Label = $Toast/Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.visible = false
	if not EventBus.request_invalid_feedback.is_connected(_on_invalid_feedback):
		EventBus.request_invalid_feedback.connect(_on_invalid_feedback)

func show_toast(message: String, invalid: bool = false) -> void:
	if message.is_empty():
		return
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	toast.color = Color("6f2929") if invalid else Color("153d3a")
	toast_label.text = message
	toast.modulate.a = 1.0
	toast.visible = true
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.1)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.25)
	_toast_tween.finished.connect(func() -> void: toast.visible = false)


func _on_invalid_feedback(reason: StringName) -> void:
	var message := "ACTION UNAVAILABLE"
	if reason != &"":
		message = String(reason).replace("_", " ").to_upper()
	show_toast(message, true)
