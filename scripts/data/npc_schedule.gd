class_name NpcSchedule
extends Resource

@export var id: StringName = &""
@export_range(8.0, 160.0, 1.0) var move_speed: float = 42.0
@export var seasons: Array[SeasonMeta.SeasonType] = []
@export var months: Array[int] = []
@export var weekdays: Array[int] = []
@export_range(0, 99, 1) var priority: int = 0
@export_range(0, 1439, 1) var start_minute: int = 360
@export var map_id: StringName = &"farm"
@export var target_position: Vector2 = Vector2.ZERO
@export var behavior_id: StringName = &"idle"
@export var wander_zone: Vector2 = Vector2.ZERO
@export_range(0.0, 10.0, 1.0) var wander_interval: float = 10.0

func matches_date(season: SeasonMeta.SeasonType, month: int, weekday: int) -> bool:
	return (
		(seasons.is_empty() or season in seasons)
		and (months.is_empty() or month in months)
		and (weekdays.is_empty() or weekday in weekdays)
	)
