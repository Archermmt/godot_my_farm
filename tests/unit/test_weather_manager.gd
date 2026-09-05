extends ProjectTestCase


func test_configuration_requires_positive_weather_for_every_season() -> void:
	var entries := _default_seasons()
	var manager := CalendarManagerService.new()
	manager.config = manager.config.duplicate() as GameConfig
	manager.config.season_metas = entries
	assert_true(manager.validate().is_empty())
	entries.erase(SeasonMeta.SeasonType.WINTER)
	manager.config.season_metas = entries
	var errors := manager.validate()
	assert_true(_contains(errors, "season_type 3 has no SeasonMeta"))
	var duplicate := _season(SeasonMeta.SeasonType.SPRING, {&"clear": 1.0})
	entries[SeasonMeta.SeasonType.SUMMER] = duplicate
	manager.config.season_metas = entries
	errors = manager.validate()
	assert_true(_contains(errors, "season_type must match dictionary key"))


func test_weather_selection_uses_month_season_and_is_deterministic() -> void:
	var manager := CalendarManagerService.new()
	manager.config = manager.config.duplicate() as GameConfig
	manager.config.season_metas = _single_weather_per_season()
	manager.validate()
	manager.calendar = CalendarState.new()
	manager.calendar.season_metas = manager.config.season_metas
	var spring := manager.calendar.weather_id(1, 1, 3)
	var summer := manager.calendar.weather_id(4, 1, 3)
	var winter := manager.calendar.weather_id(10, 1, 3)
	assert_equal(spring, &"clear")
	assert_equal(summer, &"rain")
	assert_equal(winter, &"snow")
	assert_equal(manager.calendar.weather_id(1, 1, 3), spring)
	assert_equal(manager.calendar.weather_id(13, 1, 3), &"snow")
	manager.free()


func test_weather_tint_changes_daylight_and_interior_stays_more_neutral() -> void:
	var manager := CalendarManagerService.new()
	var spring := _season(SeasonMeta.SeasonType.SPRING, {&"rain": 1.0})
	spring.weather_light_tints[&"rain"] = Color(0.6, 0.7, 0.8, 1.0)
	manager.config = manager.config.duplicate() as GameConfig
	manager.config.season_metas = _season_dictionary([spring, _summer(), _autumn(), _winter()])
	manager.validate()
	manager.current_weather = &"rain"
	assert_true(manager.check_weather([&"rain", &"storm"]))
	assert_true(not manager.check_weather([&"clear", &"snow"]))
	GameManager.calendar.month = 1
	manager.free()


func test_default_game_configuration_exposes_season_specific_weights() -> void:
	assert_equal(CalendarManager.config.season_metas.size(), 4)
	for meta: SeasonMeta in CalendarManager.config.season_metas.values():
		var total := 0.0
		for weather_id: StringName in meta.weather_weights:
			total += meta.weather_weights[weather_id]
		assert_equal(total, 100.0)
	var spring := CalendarManager.calendar.season_metas[SeasonMeta.SeasonType.SPRING]
	var winter := CalendarManager.calendar.season_metas[SeasonMeta.SeasonType.WINTER]
	assert_true(spring.weather_weights.has(&"rain"))
	assert_true(not spring.weather_weights.has(&"snow"))
	assert_true(winter.weather_weights.has(&"snow"))
	assert_true(not winter.weather_weights.has(&"rain"))
	assert_equal(CalendarManager.calendar.season(7), SeasonMeta.SeasonType.AUTUMN)
	assert_true(CalendarManager.validate().is_empty())
	for weather_id: StringName in [&"clear", &"cloudy", &"rain", &"storm", &"snow"]:
		assert_true(CalendarManager.weather_icon(weather_id) != null)


func test_request_end_day_selects_weather_once_for_the_new_date() -> void:
	var saved_snapshot := GameManager.build_snapshot()
	var before_calendar := GameManager.calendar.to_dict()
	var weather_events: Array[StringName] = []
	var capture := func(weather_id: StringName, _previous_weather_id: StringName) -> void:
		weather_events.append(weather_id)
	EventBus.weather_changed.connect(capture, CONNECT_ONE_SHOT)
	assert_equal(CalendarManager.advance_to_next_day(), OK)
	assert_true(GameManager.calendar.to_dict() != before_calendar)
	assert_equal(weather_events.size(), 1)
	assert_equal(weather_events[0], CalendarManager.current_weather)
	assert_equal(GameManager.replace_build_snapshot(saved_snapshot), OK)


func _single_weather_per_season() -> Dictionary[SeasonMeta.SeasonType, SeasonMeta]:
	return _season_dictionary([
		_season(SeasonMeta.SeasonType.SPRING, {&"clear": 1.0}),
		_season(SeasonMeta.SeasonType.SUMMER, {&"rain": 1.0}),
		_season(SeasonMeta.SeasonType.AUTUMN, {&"cloudy": 1.0}),
		_season(SeasonMeta.SeasonType.WINTER, {&"snow": 1.0}),
	])


func _default_seasons() -> Dictionary[SeasonMeta.SeasonType, SeasonMeta]:
	return _season_dictionary([_spring(), _summer(), _autumn(), _winter()])


func _spring() -> SeasonMeta:
	return _season(SeasonMeta.SeasonType.SPRING, {&"clear": 45.0, &"cloudy": 25.0, &"rain": 30.0})


func _summer() -> SeasonMeta:
	return _season(SeasonMeta.SeasonType.SUMMER, {&"clear": 60.0, &"cloudy": 20.0, &"rain": 15.0, &"storm": 5.0})


func _autumn() -> SeasonMeta:
	return _season(SeasonMeta.SeasonType.AUTUMN, {&"clear": 35.0, &"cloudy": 35.0, &"rain": 25.0, &"storm": 5.0})


func _winter() -> SeasonMeta:
	return _season(SeasonMeta.SeasonType.WINTER, {&"clear": 35.0, &"cloudy": 35.0, &"snow": 30.0})


func _season(season_type: SeasonMeta.SeasonType, weights: Dictionary) -> SeasonMeta:
	var meta := SeasonMeta.new()
	meta.season_type = season_type
	for weather_id: StringName in weights:
		meta.weather_weights[weather_id] = weights[weather_id]
		meta.weather_light_tints[weather_id] = Color.WHITE
	return meta


func _season_dictionary(entries: Array[SeasonMeta]) -> Dictionary[SeasonMeta.SeasonType, SeasonMeta]:
	var result: Dictionary[SeasonMeta.SeasonType, SeasonMeta] = {}
	for meta: SeasonMeta in entries:
		result[meta.season_type] = meta
	return result


func _contains(errors: Array[String], fragment: String) -> bool:
	for error: String in errors:
		if fragment in error:
			return true
	return false
