extends ProjectTestCase


func test_schedule_filters_priority_fallback_and_cross_midnight() -> void:
	var schedule := NpcSchedule.new()
	schedule.npc_id = &"npc_test"
	schedule.fallback_map_id = &"farm"
	schedule.fallback_cell = Vector2i(2, 2)
	var regular := _event(&"regular", 480, 120, &"farm", Vector2i(4, 4))
	regular.seasons = [SeasonMeta.SeasonType.SPRING]
	regular.months = [1]
	regular.weekdays = [1]
	var priority := _event(&"priority", 510, 30, &"field", Vector2i(6, 6))
	priority.seasons = [SeasonMeta.SeasonType.SPRING]
	priority.months = [1]
	priority.weekdays = [1]
	priority.priority = 1
	var overnight := _event(&"overnight", 1380, 120, &"beach", Vector2i(8, 8))
	overnight.weekdays = [1]
	schedule.events = [regular, priority, overnight]
	var calendar := _calendar(1, 1, 8, 15)
	var manager := GameManagerService.new()
	manager.calendar = calendar
	assert_equal(manager.npc_active_event(schedule), regular)
	calendar.minute = 45
	assert_equal(manager.npc_active_event(schedule), priority)
	calendar.hour = 12
	calendar.minute = 0
	assert_equal(manager.npc_assignment(schedule)["event_id"], &"fallback")
	assert_equal(manager.npc_assignment(schedule)["cell"], Vector2i(2, 2))
	calendar.day = 2
	calendar.weekday = 2
	calendar.hour = 0
	calendar.minute = 30
	assert_equal(manager.npc_active_event(schedule), overnight)
	manager.free()


func test_catalog_rejects_same_priority_schedule_conflicts_and_invalid_filters() -> void:
	var first := _event(&"first", 480, 120, &"farm", Vector2i.ONE)
	var second := _event(&"second", 540, 120, &"field", Vector2i.ONE)
	first.months = [1]
	second.months = [1]
	second.weekdays = [8]
	var schedule := NpcSchedule.new()
	schedule.id = &"schedule_conflict"
	schedule.npc_id = &"npc_conflict"
	schedule.events = [first, second]
	var schedules: Dictionary[StringName, NpcSchedule] = {schedule.id: schedule}
	var catalog := DataCatalogService.new()
	var errors := catalog.validate()
	assert_true(_contains(errors, "overlap at priority"))
	assert_true(_contains(errors, "weekday 8 invalid"))
	second.priority = 1
	errors = catalog.validate()
	assert_true(not _contains(errors, "overlap at priority"))


func test_portal_graph_routes_field_to_beach_through_farm() -> void:
	var manager := GameManagerService.new()
	assert_equal(manager.npc_portal_route(&"field", &"beach"), [&"field", &"farm", &"beach"])
	assert_equal(manager.npc_portal_route(&"farm", &"field"), [&"farm", &"field"])
	assert_equal(manager.npc_portal_route(&"missing", &"farm"), [])
	assert_equal(manager.npc_portal_arrival_cell(&"field", &"beach", Vector2i.ZERO), Vector2i(29, 2))
	manager.free()


func test_npc_scene_uses_native_navigation_and_animation_components() -> void:
	var scene := load("res://scenes/actors/npcs/npc.tscn") as PackedScene
	assert_true(scene != null)
	var npc := scene.instantiate() as FarmNpc
	assert_true(npc.get_node_or_null("NavigationAgent2D") is NavigationAgent2D)
	assert_true(npc.get_node_or_null("AnimationPlayer") is AnimationPlayer)
	assert_true(npc.get_node_or_null("Visual/Sprite") is Sprite2D)
	npc.free()


func test_game_manager_initializes_one_npc_per_starting_map() -> void:
	var manager := GameManagerService.new()
	assert_equal(manager.new_game(77), OK)
	assert_equal(manager.npcs.size(), 3)
	assert_equal(manager.get_npc(&"npc_villager").current_event_id, &"fallback")
	assert_equal(manager.get_npc(&"npc_fisher").current_event_id, &"morning_beach")
	assert_equal(manager.get_npc(&"npc_ranger").current_event_id, &"day_field")
	assert_equal(manager.get_npc(&"npc_villager").map_id, &"farm")
	assert_equal(manager.get_npc(&"npc_ranger").map_id, &"field")
	assert_equal(manager.get_npc(&"npc_fisher").map_id, &"beach")
	var field := (load("res://scenes/maps/field/field.tscn") as PackedScene).instantiate() as BaseMap
	var ranger := (load("res://scenes/actors/npcs/npc.tscn") as PackedScene).instantiate() as FarmNpc
	var root := (Engine.get_main_loop() as SceneTree).root
	root.add_child(field)
	root.add_child(ranger)
	assert_true(field.cells.has(manager.get_npc(&"npc_ranger").cell))
	assert_true(field.check_cell(manager.get_npc(&"npc_ranger").cell, CellState.CellCondition.WALKABLE))
	assert_equal(ranger.bind(manager.get_npc(&"npc_ranger"), field), OK)
	assert_equal(ranger.state.schedule_id, &"ranger")
	ranger.free()
	field.free()
	manager.calendar.hour = 12
	manager.calendar.minute = 0
	manager._refresh_npc_schedules()
	assert_equal(manager.get_npc(&"npc_villager").map_id, &"field")
	assert_equal(manager.get_npc(&"npc_villager").current_event_id, &"afternoon_field")
	assert_equal(manager.get_npc(&"npc_fisher").map_id, &"farm")
	assert_equal(manager.get_npc(&"npc_fisher").current_event_id, &"afternoon_farm")
	assert_equal(manager.get_npc(&"npc_ranger").map_id, &"field")
	manager.calendar.hour = 17
	manager._refresh_npc_schedules()
	assert_equal(manager.get_npc(&"npc_villager").map_id, &"farm")
	assert_equal(manager.get_npc(&"npc_fisher").map_id, &"beach")
	assert_equal(manager.get_npc(&"npc_ranger").map_id, &"field")
	manager.free()


func _event(id: StringName, start: int, duration: int, map_id: StringName, cell: Vector2i) -> NpcScheduleEvent:
	var event := NpcScheduleEvent.new()
	event.id = id
	event.start_minute = start
	event.duration_minutes = duration
	event.map_id = map_id
	event.target_cell = cell
	return event


func _calendar(month: int, weekday: int, hour: int, minute: int) -> CalendarState:
	var calendar := CalendarState.new()
	calendar.month = month
	calendar.weekday = weekday
	calendar.hour = hour
	calendar.minute = minute
	return calendar


func _map(width: int, height: int) -> BaseMap:
	var map := BaseMap.new()
	for y: int in height:
		for x: int in width:
			var cell_state := CellState.new()
			cell_state.flags = CellState.CellFlag.BASE
			map.cells[Vector2i(x, y)] = MapCell.new(Vector2i(x, y), cell_state)
	return map


func _contains(errors: Array[String], fragment: String) -> bool:
	for error: String in errors:
		if fragment in error:
			return true
	return false
