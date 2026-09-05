class_name ActionEffect
extends Node2D

const COLORS := {
	&"till": Color("d8a45c"),
	&"water": Color("66b7d5"),
	&"cut": Color("83bd62"),
	&"harvest": Color("f0c94d"),
	&"mine": Color("a8b0b0"),
	&"chop": Color("d58a55"),
}

@export_range(0.05, 2.0, 0.05) var lifetime: float = 0.45

var points: PackedVector2Array = PackedVector2Array()
var effect_color: Color = Color.WHITE
var _playing := false


func play(event_id: StringName, positions: Array[Vector2]) -> void:
	_playing = true
	effect_color = COLORS.get(event_id, Color("e9d986")) as Color
	points.clear()
	for position: Vector2 in positions:
		points.append(to_local(position))
	queue_redraw()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(queue_free)
func stop() -> void:
	_playing = false
	modulate.a = 1.0
	points.clear()
	queue_redraw()

func is_playing() -> bool:
	return _playing


func _draw() -> void:
	for point: Vector2 in points:
		draw_circle(point, 7.0, Color(effect_color, 0.24))
		draw_arc(point, 8.5, 0.0, TAU, 16, effect_color, 1.5)
