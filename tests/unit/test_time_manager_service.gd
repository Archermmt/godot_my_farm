extends ProjectTestCase


func test_calendar_advances_time_and_exposes_pause_reasons() -> void:
	CalendarManager.stop()
	CalendarManager.start()
	var before := CalendarManager.minute
	assert_equal(CalendarManager.advance_minutes(1), OK)
	assert_equal(CalendarManager.minute, (before + 1) % 60)
	assert_equal(CalendarManager.pause(&"test"), OK)
	assert_true(CalendarManager.is_paused())
	assert_equal(CalendarManager.resume(&"test"), OK)
	assert_true(not CalendarManager.is_paused())
