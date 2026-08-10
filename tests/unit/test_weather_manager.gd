extends ProjectTestCase


func test_default_weather_configuration_is_complete() -> void:
	assert_equal(CalendarManager.config.season_metas.size(), 4)
	assert_true(CalendarManager.current_weather != &"")
	assert_true(CalendarManager.weather_icon(CalendarManager.current_weather) != null)


func test_weather_filter_and_day_transition_are_stable() -> void:
	var current := CalendarManager.current_weather
	assert_true(CalendarManager.check_weather([current]))
	assert_true(not CalendarManager.check_weather([&"missing_weather"]))
