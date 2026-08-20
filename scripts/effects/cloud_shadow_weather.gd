class_name CloudShadowWeatherEffect
extends Node2D

@export var shadow_texture: Texture2D
@export_range(1, 64, 1) var clear_shadow_count: int = 12
@export_range(1, 64, 1) var cloudy_shadow_count: int = 24
@export_range(0.2, 3.0, 0.05) var clear_shadow_scale: float = 0.9
@export_range(0.2, 3.0, 0.05) var cloudy_shadow_scale: float = 1.5
@export_range(0.05, 0.8, 0.01) var clear_shadow_alpha: float = 0.34
@export_range(0.05, 1.0, 0.01) var cloudy_shadow_alpha: float = 0.72
@export var clear_shadow_color: Color = Color(0.38, 0.43, 0.48, 1.0)
@export var cloudy_shadow_color: Color = Color(0.16, 0.20, 0.25, 1.0)
@export_range(0.0, 0.35, 0.01) var shape_variation: float = 0.18
@export_range(0.0, 30.0, 0.5) var drift_speed: float = 5.0

var _bounds := Rect2()
var _rng := RandomNumberGenerator.new()


func configure(weather_id: StringName, map: BaseMap) -> void:
	if map == null or shadow_texture == null:
		queue_free()
		return
	_bounds = map.map_bounds_world()
	_rng.seed = hash([weather_id, map.name])
	for child: Node in get_children():
		child.queue_free()
	var is_cloudy := weather_id == &"cloudy"
	var count := cloudy_shadow_count if is_cloudy else clear_shadow_count
	var shadow_scale := cloudy_shadow_scale if is_cloudy else clear_shadow_scale
	var shadow_alpha := cloudy_shadow_alpha if is_cloudy else clear_shadow_alpha
	var shadow_color := cloudy_shadow_color if is_cloudy else clear_shadow_color
	var columns := maxi(1, ceili(sqrt(float(count) * _bounds.size.x / maxf(_bounds.size.y, 1.0))))
	var rows := maxi(1, ceili(float(count) / float(columns)))
	var spacing := Vector2(_bounds.size.x / float(columns), _bounds.size.y / float(rows))
	for index: int in count:
		var shadow := Sprite2D.new()
		shadow.texture = shadow_texture
		var grid_cell := Vector2i(index % columns, floori(float(index) / float(columns)))
		shadow.position = _bounds.position + Vector2(grid_cell) * spacing + spacing * Vector2(
			_rng.randf_range(0.25, 0.75),
			_rng.randf_range(0.25, 0.75)
		)
		# Vary each shadow's silhouette without requiring a separate texture for
		# every cloud: non-uniform scale and rotation produce visibly different
		# drifting shapes while keeping the effect editor-configurable.
		var variation := _rng.randf_range(1.0 - shape_variation, 1.0 + shape_variation)
		shadow.scale = Vector2(
			shadow_scale * variation * _rng.randf_range(0.82, 1.22),
			shadow_scale * variation * _rng.randf_range(0.68, 1.12)
		)
		shadow.rotation = _rng.randf_range(-0.16, 0.16)
		var tone := _rng.randf_range(0.88, 1.08)
		shadow.modulate = Color(
			clampf(shadow_color.r * tone, 0.0, 1.0),
			clampf(shadow_color.g * tone, 0.0, 1.0),
			clampf(shadow_color.b * tone, 0.0, 1.0),
			shadow_alpha * _rng.randf_range(0.88, 1.08)
		)
		# Render above all ground projections (Base/Dug/Watered) while the
		# map's EntityHosts and the global ActorHost remain above at z=3.
		shadow.z_index = 0
		shadow.set_meta("cloud_shadow", true)
		add_child(shadow)


func _process(delta: float) -> void:
	if _bounds.size == Vector2.ZERO:
		return
	for child: Node in get_children():
		if child is not Sprite2D:
			continue
		var shadow := child as Sprite2D
		shadow.position.x += drift_speed * delta
		if shadow.position.x > _bounds.end.x + 120.0:
			shadow.position.x = _bounds.position.x - 120.0
