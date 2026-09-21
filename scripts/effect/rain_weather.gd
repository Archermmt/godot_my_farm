class_name RainWeatherEffect
extends Node2D

@export_range(32, 1024, 1) var drops_per_map: int = 280
@export_range(8, 512, 1) var ripples_per_map: int = 36
@export_range(0.5, 3.0, 0.05) var storm_density_multiplier: float = 1.45
@export var effect_range: Vector2 = Vector2(1600, 1200)

@onready var rain: CPUParticles2D = $Rain
@onready var ripples: CPUParticles2D = $Ripples
var _camera: Camera2D = null
var _weather_id: StringName = &"rain"

func play(weather_id: StringName, _positions: Array[Vector2]) -> void:
	_weather_id = weather_id
	_camera = get_viewport().get_camera_2d()
	if rain == null or ripples == null:
		return
	var density := storm_density_multiplier if weather_id == &"storm" else 1.0
	rain.amount = maxi(1, roundi(float(drops_per_map) * density))
	ripples.amount = maxi(1, roundi(float(ripples_per_map) * density))
	_update_to_camera()
	rain.emitting = true
	ripples.emitting = true
	rain.restart()
	ripples.restart()

func _process(_delta: float) -> void:
	_update_to_camera()

func _update_to_camera() -> void:
	if rain == null or ripples == null:
		return
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_2d()
	if _camera == null:
		return
	var viewport_size := get_viewport_rect().size
	var zoom := _camera.zoom
	var visible_size := Vector2(viewport_size.x / maxf(zoom.x, 0.01), viewport_size.y / maxf(zoom.y, 0.01))
	var bounds := Rect2(_camera.global_position - visible_size * 0.5, visible_size)
	global_position = Vector2.ZERO
	rain.position = Vector2(bounds.get_center().x, bounds.position.y - 24.0)
	rain.emission_rect_extents = Vector2(bounds.size.x * 0.5 + 64.0, 8.0)
	rain.lifetime = maxf(1.2, (bounds.size.y + 160.0) / 420.0)
	ripples.position = bounds.get_center()
	ripples.emission_rect_extents = bounds.size * 0.5
