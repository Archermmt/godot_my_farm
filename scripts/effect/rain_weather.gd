class_name RainWeatherEffect
extends Node2D

@export_range(32, 1024, 1) var drops_per_map: int = 280
@export_range(8, 512, 1) var ripples_per_map: int = 36
@export_range(0.5, 3.0, 0.05) var storm_density_multiplier: float = 1.45
@export var effect_range: Vector2 = Vector2(1600, 1200)

@onready var rain: CPUParticles2D = $Rain
@onready var ripples: CPUParticles2D = $Ripples


func play(weather_id: StringName, _positions: Array[Vector2]) -> void:
	if rain == null or ripples == null:
		return
	var bounds := Rect2(-effect_range * 0.5, effect_range)
	var density := storm_density_multiplier if weather_id == &"storm" else 1.0
	rain.amount = maxi(1, roundi(float(drops_per_map) * density))
	ripples.amount = maxi(1, roundi(float(ripples_per_map) * density))
	rain.position = to_local(Vector2(bounds.get_center().x, bounds.position.y - 24.0))
	rain.emission_rect_extents = Vector2(bounds.size.x * 0.5 + 32.0, 8.0)
	rain.lifetime = maxf(1.2, (bounds.size.y + 160.0) / 420.0)
	ripples.position = to_local(bounds.get_center())
	ripples.emission_rect_extents = bounds.size * 0.5
	rain.emitting = true
	ripples.emitting = true
	rain.restart()
	ripples.restart()
