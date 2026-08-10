class_name AudioDefinition
extends Resource

enum Channel { MUSIC, AMBIENT, SFX, UI }

@export var channel: Channel = Channel.SFX
@export var stream: AudioStream = null
@export_range(-40.0, 6.0, 0.5) var volume_db: float = -8.0
@export_range(0, 2000, 10) var cooldown_msec: int = 80
@export_range(1, 8, 1) var max_instances: int = 2
@export_range(80.0, 1600.0, 1.0) var placeholder_frequency: float = 440.0
@export_range(0.03, 2.0, 0.01) var placeholder_duration: float = 0.12
@export var loop: bool = false


func bus_name() -> StringName:
	match channel:
		Channel.MUSIC:
			return &"Music"
		Channel.AMBIENT:
			return &"Ambient"
		Channel.UI:
			return &"UI"
	return &"SFX"
