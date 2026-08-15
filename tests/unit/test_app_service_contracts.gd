extends ProjectTestCase


func test_event_bus_declares_only_confirmed_signal_surface() -> void:
	var service := EventBusService.new()
	for signal_name: StringName in [
		&"map_change_requested",
		&"map_change_failed",
		&"map_changed",
		&"time_advanced",
		&"day_advanced",
		&"weather_changed",
		&"inventory_changed",
		&"container_changed",
		&"bar_selection_changed",
		&"active_hand_changed",
		&"cells_tool_used",
		&"cell_projection_failed",
		&"request_tool_feedback",
		&"request_invalid_feedback",
		&"save_completed",
		&"load_completed",
	]:
		assert_true(service.has_signal(signal_name))
	service.free()


func test_scene_manager_requires_explicit_hosts() -> void:
	var router := SceneManagerService.new()
	assert_equal(router.register_hosts(null, null, null, null), ERR_INVALID_PARAMETER)
	var map_host := Node2D.new()
	var actor_host := Node2D.new()
	var ui_layer := CanvasLayer.new()
	var overlay := ColorRect.new()
	assert_equal(router.register_hosts(map_host, actor_host, ui_layer, overlay), OK)
	assert_true(router.has_registered_hosts())
	assert_equal(router.request_map_change(&"farm", &"default"), ERR_UNCONFIGURED)
	assert_equal(router.registered_map_ids(), [&"cabin", &"farm", &"field"])
	router.unregister_hosts(map_host)
	assert_true(not router.has_registered_hosts())
	overlay.free()
	ui_layer.free()
	actor_host.free()
	map_host.free()
	router.free()


func test_unconfigured_save_and_audio_operations_return_errors() -> void:
	var game_manager := GameManagerService.new()
	var audio_manager := AudioManagerService.new()
	var effect_manager := EffectManagerService.new()
	assert_equal(game_manager.save_slot(0), ERR_UNAVAILABLE)
	assert_equal(game_manager.load_slot(0), ERR_UNAVAILABLE)
	assert_equal(audio_manager.play_event(&"ui_confirm"), ERR_UNCONFIGURED)
	assert_equal(audio_manager.stop_event(&"ui_confirm"), ERR_DOES_NOT_EXIST)
	assert_equal(effect_manager.definition_count(), 0)
	game_manager.free()
	audio_manager.free()
	effect_manager.free()
