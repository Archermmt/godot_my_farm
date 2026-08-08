class_name CalendarState
extends RefCounted

const SEASONS: Array[StringName] = [&"spring", &"summer", &"autumn", &"winter"]

var year: int = 1
var month: int = 1
var day: int = 1
var weekday: int = 1
var hour: int = 6
var minute: int = 0


func season() -> StringName:
	var index: int = floori(float(clampi(month, 1, 12) - 1) / 3.0)
	return SEASONS[index]


func minute_of_day() -> int:
	return hour * 60 + minute


func to_dict() -> Dictionary:
	return {
		"year": year,
		"month": month,
		"day": day,
		"weekday": weekday,
		"hour": hour,
		"minute": minute,
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
	if raw_year < 1 or raw_month < 1 or raw_month > 12 or raw_day < 1 or raw_day > 28:
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
	return restored
