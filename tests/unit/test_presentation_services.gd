extends ProjectTestCase


func test_audio_definitions_pool_and_high_frequency_throttle_are_bounded() -> void:
	var manager := AudioManagerService.new()
	var root := (Engine.get_main_loop() as SceneTree).root
	root.add_child(manager)
	assert_equal(manager.configure_definitions(AudioManager.definitions), OK)
	assert_equal(manager.definition_count(), 18)
	assert_equal(manager.play_event(&"ui_confirm"), OK)
	assert_equal(manager.play_event(&"ui_confirm"), ERR_BUSY)
	for _index: int in 100:
		manager.play_event(&"footstep")
	assert_true(manager.pool_size(&"SFX") <= 10)
	assert_true(manager.active_event_count(&"footstep") <= 1)
	assert_equal(manager.play_event(&"missing_event"), ERR_DOES_NOT_EXIST)
	manager._on_map_changed(&"farm")
	assert_equal(manager.current_loop_event(&"Ambient"), &"ambient_farm")
	assert_equal(manager.current_loop_event(&"Music"), &"music_farm")
	manager._on_map_changed(&"field")
	assert_equal(manager.current_loop_event(&"Ambient"), &"ambient_field")
	assert_equal(manager.current_loop_event(&"Music"), &"music_field")
	manager.free()


func test_multicell_feedback_uses_one_bounded_effect_and_invalid_uses_no_success_effect() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var effect_host := Node2D.new()
	root.add_child(effect_host)
	var manager := EffectManagerService.new()
	root.add_child(manager)
	var definition := EffectDefinition.new()
	definition.effect_id = &"water"
	definition.scene = load("res://scenes/effects/action_effect.tscn") as PackedScene
	definition.max_instances = 8
	assert_true(manager.configure_definitions([definition]).is_empty())
	var cells: Array[Vector2i] = []
	for x: int in 81:
		cells.append(Vector2i(x % 9, x / 9))
	for _index: int in 50:
		manager.play_action(&"water", cells, null, effect_host)
	assert_true(effect_host.get_child_count() > 0)
	assert_true(effect_host.get_child_count() <= 8)
	manager.free()
	effect_host.free()


func test_presentation_layout_uses_shared_theme_and_safe_fixed_panels() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var inventory := (load("res://scenes/ui/inventory_interface.tscn") as PackedScene).instantiate() as InventoryUI
	var panel := inventory.get_node("InventoryPanel") as ColorRect
	assert_true(inventory.theme != null)
	assert_equal(panel.offset_left, -300.0)
	assert_equal(panel.offset_right, 300.0)
	assert_equal(panel.offset_top, -156.0)
	assert_equal(panel.offset_bottom, 156.0)
	var presentation := (load("res://scenes/ui/presentation_layer.tscn") as PackedScene).instantiate() as PresentationController
	var toast := presentation.get_node("Toast") as ColorRect
	assert_equal(toast.offset_left, -140.0)
	assert_equal(toast.offset_right, 140.0)
	var status := (load("res://scenes/ui/game_status_panel.tscn") as PackedScene).instantiate() as GameStatusPanel
	root.add_child(status)
	var calendar_label := status.get_node("Panel/Calendar") as Label
	var font := calendar_label.get_theme_font(&"font")
	var font_size := calendar_label.get_theme_font_size(&"font_size")
	var rendered_width := 0.0
	for line: String in calendar_label.text.split("\n"):
		rendered_width = maxf(rendered_width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	assert_true(
		rendered_width <= calendar_label.size.x,
		"Calendar label requires %.1f px but only has %.1f px" % [rendered_width, calendar_label.size.x]
	)
	assert_true(
		font.get_height(font_size) * calendar_label.get_line_count() <= calendar_label.size.y,
		"Calendar label text does not fit its height"
	)
	inventory.free()
	presentation.free()
	status.free()


func test_weather_manager_samples_time_directly_and_keeps_interior_more_neutral() -> void:
	var manager := WeatherManagerService.new()
	var morning := manager.sampled_light_color(6, 0)
	var noon := manager.sampled_light_color(12, 0)
	var evening := manager.sampled_light_color(18, 0)
	var night := manager.sampled_light_color(23, 0)
	assert_true(morning != noon)
	assert_true(noon != evening)
	assert_true(evening != night)
	assert_equal(night, manager.night_color)
	var interior_night := manager.sampled_light_color(23, 0, true)
	assert_true(interior_night.get_luminance() > night.get_luminance())
	manager.free()
