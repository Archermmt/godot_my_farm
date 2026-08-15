extends ProjectTestCase


func test_configuration_requires_positive_weather_for_every_season() -> void:
	var entries := _default_seasons()
	assert_equal(WeatherManagerService.validate_configuration(entries), [])
	entries.pop_back()
	var errors := WeatherManagerService.validate_configuration(entries)
	assert_true(_contains(errors, "season_type 3 has no SeasonMeta"))
	var duplicate := _season(SeasonMeta.SeasonType.SPRING, &"spring_again", [1], {&"clear": 1.0})
	entries.append(duplicate)
	errors = WeatherManagerService.validate_configuration(entries)
	assert_true(_contains(errors, "month 1 is assigned to multiple seasons"))


func test_weather_selection_uses_month_season_and_is_deterministic() -> void:
	var manager := WeatherManagerService.new()
	manager.configure_seasons(_single_weather_per_season())
	var spring := manager.weather_for_date(1, 42, 1, 3)
	var summer := manager.weather_for_date(4, 42, 1, 3)
	var winter := manager.weather_for_date(10, 42, 1, 3)
	assert_equal(spring, &"clear")
	assert_equal(summer, &"rain")
	assert_equal(winter, &"snow")
	assert_equal(manager.weather_for_date(1, 42, 1, 3), spring)
	assert_equal(manager.weather_for_date(13, 42, 1, 3), &"snow")
	manager.free()


func test_weather_tint_changes_daylight_and_interior_stays_more_neutral() -> void:
	var manager := WeatherManagerService.new()
	var spring := _season(SeasonMeta.SeasonType.SPRING, &"spring", [1, 2, 3], {&"rain": 1.0})
	spring.weather_light_tints[&"rain"] = Color(0.6, 0.7, 0.8, 1.0)
	manager.configure_seasons([spring, _summer(), _autumn(), _winter()])
	manager.current_weather = &"rain"
	GameManager.calendar.month = 1
	var outdoor := manager.sampled_light_color(12, 0)
	var interior := manager.sampled_light_color(12, 0, true)
	assert_equal(outdoor, spring.weather_light_tints[&"rain"])
	assert_true(interior.get_luminance() > outdoor.get_luminance())
	assert_true(interior != outdoor)
	manager.free()


func test_default_autoload_configuration_exposes_season_specific_weights() -> void:
	assert_equal(WeatherManager.season_metas.size(), 4)
	for meta: SeasonMeta in WeatherManager.season_metas:
		var total := 0.0
		for weather_id: StringName in meta.weather_weights:
			total += meta.weather_weights[weather_id]
		assert_equal(total, 100.0)
	var spring := WeatherManager.season_for_type(SeasonMeta.SeasonType.SPRING)
	var winter := WeatherManager.season_for_type(SeasonMeta.SeasonType.WINTER)
	assert_true(spring.weather_weights.has(&"rain"))
	assert_true(not spring.weather_weights.has(&"snow"))
	assert_true(winter.weather_weights.has(&"snow"))
	assert_true(not winter.weather_weights.has(&"rain"))
	assert_equal(WeatherManager.season_id_for_month(7), &"autumn")


func test_skip_day_selects_weather_once_for_the_new_date() -> void:
	var saved_snapshot := GameManager.build_snapshot()
	var before_calendar := GameManager.calendar.to_dict()
	var weather_events: Array[StringName] = []
	var capture := func(weather_id: StringName, _previous_weather_id: StringName) -> void:
		weather_events.append(weather_id)
	EventBus.weather_changed.connect(capture, CONNECT_ONE_SHOT)
	assert_equal(GameManager.skip_day(), OK)
	assert_true(GameManager.calendar.to_dict() != before_calendar)
	assert_equal(weather_events.size(), 1)
	assert_equal(weather_events[0], WeatherManager.current_weather_id())
	assert_equal(GameManager.replace_build_snapshot(saved_snapshot), OK)


func _single_weather_per_season() -> Array[SeasonMeta]:
	return [
		_season(SeasonMeta.SeasonType.SPRING, &"spring", [1, 2, 3], {&"clear": 1.0}),
		_season(SeasonMeta.SeasonType.SUMMER, &"summer", [4, 5, 6], {&"rain": 1.0}),
		_season(SeasonMeta.SeasonType.AUTUMN, &"autumn", [7, 8, 9], {&"cloudy": 1.0}),
		_season(SeasonMeta.SeasonType.WINTER, &"winter", [10, 11, 12], {&"snow": 1.0}),
	]


func _default_seasons() -> Array[SeasonMeta]:
	return [_spring(), _summer(), _autumn(), _winter()]


func _spring() -> SeasonMeta:
	return _season(SeasonMeta.SeasonType.SPRING, &"spring", [1, 2, 3], {&"clear": 45.0, &"cloudy": 25.0, &"rain": 30.0})


func _summer() -> SeasonMeta:
	return _season(SeasonMeta.SeasonType.SUMMER, &"summer", [4, 5, 6], {&"clear": 60.0, &"cloudy": 20.0, &"rain": 15.0, &"storm": 5.0})


func _autumn() -> SeasonMeta:
	return _season(SeasonMeta.SeasonType.AUTUMN, &"autumn", [7, 8, 9], {&"clear": 35.0, &"cloudy": 35.0, &"rain": 25.0, &"storm": 5.0})


func _winter() -> SeasonMeta:
	return _season(SeasonMeta.SeasonType.WINTER, &"winter", [10, 11, 12], {&"clear": 35.0, &"cloudy": 35.0, &"snow": 30.0})


func _season(season_type: SeasonMeta.SeasonType, season_id: StringName, months: Array[int], weights: Dictionary) -> SeasonMeta:
	var meta := SeasonMeta.new()
	meta.season_type = season_type
	meta.season_id = season_id
	meta.months = months
	for weather_id: StringName in weights:
		meta.weather_weights[weather_id] = weights[weather_id]
		meta.weather_light_tints[weather_id] = Color.WHITE
	return meta


func _contains(errors: Array[String], fragment: String) -> bool:
	for error: String in errors:
		if fragment in error:
			return true
	return false
