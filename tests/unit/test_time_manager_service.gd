extends ProjectTestCase


func test_pause_reasons_stack_until_all_are_resumed() -> void:
	var service := GameManagerService.new()
	service.start()
	assert_true(service.can_advance())
	assert_equal(service.pause(&"inventory"), OK)
	assert_equal(service.pause(&"scene_transition"), OK)
	assert_true(service.is_paused())
	assert_true(not service.can_advance())
	var reasons: Array[StringName] = service.pause_reasons()
	assert_equal(reasons.size(), 2)
	assert_true(reasons.has(&"inventory"))
	assert_true(reasons.has(&"scene_transition"))
	assert_equal(service.resume(&"inventory"), OK)
	assert_true(service.is_paused())
	assert_true(not service.can_advance())
	assert_equal(service.resume(&"scene_transition"), OK)
	assert_true(not service.is_paused())
	assert_true(service.can_advance())
	service.free()


func test_pause_api_rejects_empty_or_unknown_reason() -> void:
	var service := GameManagerService.new()
	assert_equal(service.pause(&""), ERR_INVALID_PARAMETER)
	assert_equal(service.resume(&""), ERR_INVALID_PARAMETER)
	assert_equal(service.resume(&"not_paused"), ERR_DOES_NOT_EXIST)
	service.free()


func test_reset_restores_calendar_and_stops_time() -> void:
	var service := GameManagerService.new()
	service.calendar.day = 8
	service.start()
	service.pause(&"inventory")
	service.reset()
	assert_true(not service.is_running())
	assert_true(not service.is_paused())
	assert_equal(service.calendar.to_dict(), CalendarState.new().to_dict())
	service.free()
