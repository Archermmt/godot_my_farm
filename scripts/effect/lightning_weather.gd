class_name LightningWeatherEffect
extends Node2D

@export_range(4.0, 60.0, 0.5) var minimum_interval: float = 9.0
@export_range(5.0, 90.0, 0.5) var maximum_interval: float = 24.0
@export_range(0.03, 0.5, 0.01) var flash_duration: float = 0.12
@export_range(0.1, 1.0, 0.01) var flash_alpha: float = 0.42

@onready var timer: Timer = $Timer
@onready var flash: ColorRect = $WeatherFlash/Flash
@onready var bolt: TextureRect = $WeatherFlash/Bolt
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if flash != null:
		flash.size = get_viewport_rect().size
	if bolt != null:
		bolt.position = (get_viewport_rect().size - bolt.size) * 0.5
	if timer != null:
		timer.timeout.connect(_on_timer_timeout)
		_schedule_next()
	if flash != null:
		flash.color = Color(1.0, 1.0, 0.9, 0.0)
	if bolt != null:
		bolt.visible = false


func _on_timer_timeout() -> void:
	if flash == null:
		return
	bolt.visible = true
	var flash_tween := create_tween()
	flash_tween.tween_property(flash, "color:a", flash_alpha, flash_duration * 0.25)
	flash_tween.tween_property(flash, "color:a", 0.0, flash_duration * 0.75)
	flash_tween.finished.connect(func() -> void:
		bolt.visible = false
	)
	_schedule_next()


func _schedule_next() -> void:
	if timer == null:
		return
	timer.wait_time = _rng.randf_range(minimum_interval, maximum_interval)
	timer.start()
