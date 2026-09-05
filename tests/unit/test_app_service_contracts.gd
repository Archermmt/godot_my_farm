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
		&"cell_projection_failed",
		&"request_tool_feedback",
		&"request_invalid_feedback",
		&"save_completed",
		&"load_completed",
	]:
		assert_true(service.has_signal(signal_name))
	service.free()


func test_map_manager_requires_explicit_hosts() -> void:
	var router := MapManagerService.new()
	assert_equal(router.validate(), ERR_UNCONFIGURED)
	assert_true(not router.has_registered_hosts())
	router.free()


func test_item_manager_owns_global_unique_id_count() -> void:
	var manager := ItemManagerService.new()
	assert_equal(manager.get_unique_id(&"tree"), &"tree_1")
	assert_equal(manager.get_unique_id(&"pickup_wood"), &"pickup_wood_2")
	manager.register_unique_id(&"rock_40")
	assert_equal(manager.get_unique_id(&"tree"), &"tree_41")
	assert_equal(manager.get_unique_id(&""), &"")
	manager.free()


func test_unconfigured_save_and_audio_operations_return_errors() -> void:
	var game_manager := GameManagerService.new()
	var audio_manager := AudioManagerService.new()
	var effect_manager := EffectManagerService.new()
	audio_manager.config = GameConfig.new()
	effect_manager.config = GameConfig.new()
	assert_equal(game_manager.save_slot(0), ERR_UNAVAILABLE)
	assert_equal(game_manager.load_slot(0), ERR_UNAVAILABLE)
	assert_equal(audio_manager.play_audio(&"ui_confirm"), ERR_UNCONFIGURED)
	assert_equal(audio_manager.stop_audio(&"ui_confirm"), ERR_DOES_NOT_EXIST)
	assert_equal(effect_manager.validate(), OK)
	game_manager.free()
	audio_manager.free()
	effect_manager.free()
