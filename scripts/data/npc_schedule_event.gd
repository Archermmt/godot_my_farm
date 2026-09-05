class_name NpcScheduleEvent
extends Resource

@export var id: StringName = &""
@export var seasons: Array[SeasonMeta.SeasonType] = []
@export var months: Array[int] = []
@export var weekdays: Array[int] = []
@export_range(0, 99, 1) var priority: int = 0
@export_range(0, 1439, 1) var start_minute: int = 360
@export_range(1, 1440, 1) var duration_minutes: int = 60
@export var map_id: StringName = &"farm"
@export var target_spawn_id: StringName = &""
@export var target_cell: Vector2i = Vector2i.ZERO
@export var behavior_id: StringName = &"idle"


func matches_date(season: SeasonMeta.SeasonType, month: int, weekday: int) -> bool:
	return (
		(seasons.is_empty() or season in seasons)
		and (months.is_empty() or month in months)
		and (weekdays.is_empty() or weekday in weekdays)
	)


func contains_minute(minute_of_day: int, from_previous_day: bool = false) -> bool:
	var end_minute := start_minute + duration_minutes
	if from_previous_day:
		return end_minute > 1440 and minute_of_day < end_minute - 1440
	return minute_of_day >= start_minute and minute_of_day < mini(end_minute, 1440)
