extends ProjectTestCase


func test_player_round_trip_preserves_ids_and_vector() -> void:
	var player := PlayerState.new()
	player.map_id = &"field"
	player.spawn_id = &"north_gate"
	player.cell = Vector2i(-3, 14)
	player.facing = &"left"
	player.gold = 42
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict())) as Dictionary
	var restored := PlayerState.from_dict(parsed)
	assert_equal(restored.map_id, &"field")
	assert_equal(typeof(restored.map_id), TYPE_STRING_NAME)
	assert_equal(restored.cell, Vector2i(-3, 14))
	assert_equal(typeof(restored.cell), TYPE_VECTOR2I)
	assert_equal(restored.gold, 42)


func test_calendar_derives_season_and_round_trips() -> void:
	var calendar := CalendarState.new()
	calendar.year = 2
	calendar.month = 7
	calendar.day = 12
	calendar.weekday = 4
	calendar.hour = 18
	calendar.minute = 35
	var restored := CalendarState.from_dict(calendar.to_dict())
	assert_equal(restored.season(), &"autumn")
	assert_equal(restored.minute_of_day(), 1115)
	assert_equal(restored.to_dict(), calendar.to_dict())
