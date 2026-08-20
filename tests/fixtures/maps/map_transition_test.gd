extends Node

const MAIN_PATH := "res://scenes/app/main.tscn"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var router: MapManagerService = get_tree().root.get_node("MapManager") as MapManagerService
	var event_bus: EventBusService = get_tree().root.get_node("EventBus") as EventBusService
	var main := (load(MAIN_PATH) as PackedScene).instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	router.config = router.config.duplicate() as GameConfig
	router.config.transition_duration = 0.0
	router.config.day_transition_duration = 0.05
	if router.current_map_id() != &"farm" or get_tree().get_nodes_in_group("player").size() != 1:
		_fail("initial farm/player contract failed")
		return
	var player := router.registered_player()
	var farm := router.current_map()
	var house := farm.get_node("House") as FarmHouse
	if (
		player == null
		or player.global_position != farm.spawn_position(&"default")
		or not house.roof_layer.visible
		or player.camera.zoom != Vector2.ONE
	):
		_fail("new game must start outside the farm house | pos=%s expected=%s roof=%s zoom=%s" % [
			player.global_position,
			farm.spawn_position(&"default"),
			house.roof_layer.visible,
			player.camera.zoom,
		])
		return
	player.global_position = house.global_position + Vector2(192, 304)
	await get_tree().physics_frame
	player.global_position = house.global_position + Vector2(192, 240)
	await get_tree().physics_frame
	await get_tree().create_timer(player.camera_zoom_duration + 0.05).timeout
	if house.roof_layer.visible or player.camera.zoom != router.config.indoor_camera_zoom:
		_fail("entering through the house door did not enable indoor presentation")
		return
	player.global_position = house.global_position + Vector2(192, 304)
	await get_tree().physics_frame
	await get_tree().create_timer(player.camera_zoom_duration + 0.05).timeout
	if house.roof_layer.visible or player.camera.zoom != Vector2.ONE:
		_fail("leaving through the house door did not restore outdoor presentation")
		return
	var duplicate_result := router.request_map_change(&"field", &"from_farm")
	var busy_result := router.request_map_change(&"beach", &"from_farm")
	if duplicate_result != OK or busy_result != ERR_BUSY:
		_fail("duplicate request contract failed | first=%s second=%s" % [error_string(duplicate_result), error_string(busy_result)])
		return
	await event_bus.map_changed
	await get_tree().process_frame
	if router.current_map_id() != &"field" or get_tree().get_nodes_in_group("player").size() != 1:
		_fail("farm -> field contract failed")
		return
	var invalid_result := router.request_map_change(&"missing", &"default")
	if invalid_result != ERR_DOES_NOT_EXIST or router.current_map_id() != &"field":
		_fail("invalid map must preserve current map")
		return
	var return_result := router.request_map_change(&"farm", &"from_field")
	if return_result != OK:
		_fail("field -> farm request failed")
		return
	await event_bus.map_changed
	await get_tree().process_frame
	if router.current_map_id() != &"farm" or get_tree().get_nodes_in_group("player").size() != 1:
		_fail("field -> farm contract failed")
		return
	var beach_result := router.request_map_change(&"beach", &"from_farm")
	if beach_result != OK:
		_fail("farm -> beach request failed")
		return
	await event_bus.map_changed
	await get_tree().process_frame
	var player_count: int = get_tree().get_nodes_in_group("player").size()
	if router.current_map_id() != &"beach" or player_count != 1 or router.is_transitioning():
		_fail("farm -> beach contract failed | map=%s players=%d transitioning=%s" % [router.current_map_id(), player_count, router.is_transitioning()])
		return
	var previous_day := GameManager.calendar.day
	if (
		GameManager.skip_day() != OK
		or GameManager.request_end_day() != OK
		or GameManager.calendar.day != previous_day
	):
		_fail("day transition must defer state changes until the iris closes")
		return
	await event_bus.map_changed
	while router.is_transitioning():
		await get_tree().process_frame
	await get_tree().physics_frame
	farm = router.current_map()
	house = farm.get_node("House") as FarmHouse
	var day_overlay := main.get_node("UILayer/DayTransitionOverlay") as ColorRect
	if (
		router.current_map_id() != &"farm"
		or GameManager.calendar.day == previous_day
		or GameManager.calendar.hour != 6
		or GameManager.calendar.minute != 0
		or player.global_position != farm.spawn_position(&"wake")
		or house.roof_layer.visible
		or day_overlay.visible
		or router.is_transitioning()
	):
		_fail("day transition did not finish at the indoor wake point | map=%s day=%d time=%02d:%02d pos=%s wake=%s roof=%s overlay=%s transitioning=%s" % [
			router.current_map_id(),
			GameManager.calendar.day,
			GameManager.calendar.hour,
			GameManager.calendar.minute,
			player.global_position,
			farm.spawn_position(&"wake"),
			house.roof_layer.visible,
			day_overlay.visible,
			router.is_transitioning(),
		])
		return
	print("[MapTransitionTest] PASS | farm -> field -> farm -> beach -> iris day wake | players=%d" % player_count)
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("[MapTransitionTest] %s" % message)
	get_tree().quit(1)
