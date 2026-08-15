class_name CalendarState
extends RefCounted

const SEASONS: Array[StringName] = [&"spring", &"summer", &"autumn", &"winter"]
const DAYS_PER_MONTH := 30
const MONTHS_PER_YEAR := 12

var year: int = 1
var month: int = 1
var day: int = 1
var weekday: int = 1
var hour: int = 6
var minute: int = 0
var season_id: StringName = &""


func season() -> StringName:
	if season_id != &"":
		return season_id
	var index: int = floori(float(clampi(month, 1, 12) - 1) / 3.0)
	return SEASONS[index]


func set_season(value: StringName) -> void:
	season_id = value


func minute_of_day() -> int:
	return hour * 60 + minute


func add_minutes(amount: int) -> void:
	if amount <= 0:
		return
	var total := minute_of_day() + amount
	var days := floori(float(total) / (24.0 * 60.0))
	var remainder := posmod(total, 24 * 60)
	hour = floori(float(remainder) / 60.0)
	minute = posmod(remainder, 60)
	for _index in range(days):
		_advance_day()


func _advance_day() -> void:
	day += 1
	weekday = 1 + (weekday % 7)
	if day > DAYS_PER_MONTH:
		day = 1
		month += 1
		if month > MONTHS_PER_YEAR:
			month = 1
			year += 1


func to_dict() -> Dictionary:
	return {
		"year": year,
		"month": month,
		"day": day,
		"weekday": weekday,
		"hour": hour,
		"minute": minute,
		"season_id": season_id,
	}


static func from_dict(data: Dictionary) -> CalendarState:
	for key: String in ["year", "month", "day", "weekday", "hour", "minute"]:
		if not SerializationUtil.has_valid_int(data, key):
			return null
	var raw_year: int = int(data.get("year", 1))
	var raw_month: int = int(data.get("month", 1))
	var raw_day: int = int(data.get("day", 1))
	var raw_weekday: int = int(data.get("weekday", 1))
	var raw_hour: int = int(data.get("hour", 6))
	var raw_minute: int = int(data.get("minute", 0))
	var raw_season_id := StringName(str(data.get("season_id", &"")))
	if raw_year < 1 or raw_month < 1 or raw_month > MONTHS_PER_YEAR or raw_day < 1 or raw_day > DAYS_PER_MONTH:
		return null
	if raw_weekday < 1 or raw_weekday > 7 or raw_hour < 0 or raw_hour > 23 or raw_minute < 0 or raw_minute > 59:
		return null
	var restored := CalendarState.new()
	restored.year = raw_year
	restored.month = raw_month
	restored.day = raw_day
	restored.weekday = raw_weekday
	restored.hour = raw_hour
	restored.minute = raw_minute
	restored.season_id = raw_season_id
	return restored
