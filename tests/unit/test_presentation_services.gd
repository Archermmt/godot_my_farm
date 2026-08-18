extends ProjectTestCase


func test_audio_definitions_pool_and_high_frequency_throttle_are_bounded() -> void:
	var manager := AudioManagerService.new()
	var root := (Engine.get_main_loop() as SceneTree).root
	root.add_child(manager)
	assert_equal(manager.configure_definitions(AudioManager.config.audio_definitions), OK)
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
	definition.scene = load("res://scenes/effects/action_effect.tscn") as PackedScene
	definition.max_instances = 8
	var definitions: Dictionary[StringName, EffectDefinition] = {&"water": definition}
	assert_true(manager.configure_definitions(definitions).is_empty())
	var cells: Array[Vector2i] = []
	for x: int in 81:
		cells.append(Vector2i(x % 9, x / 9))
	for _index: int in 50:
		manager.play_action(&"water", cells, null, effect_host)
	assert_true(effect_host.get_child_count() > 0)
	assert_true(effect_host.get_child_count() <= 8)
	manager.free()
	effect_host.free()


func test_cut_chop_mine_and_rain_are_editable_particle_scenes() -> void:
	var cut := (load("res://scenes/effects/cut_particles.tscn") as PackedScene).instantiate() as BurstParticles
	var chop := (load("res://scenes/effects/chop_particles.tscn") as PackedScene).instantiate() as BurstParticles
	var mine := (load("res://scenes/effects/mine_particles.tscn") as PackedScene).instantiate() as BurstParticles
	var rain := (load("res://scenes/effects/rain_weather.tscn") as PackedScene).instantiate() as RainWeatherEffect
	assert_true(cut.get_node("EmitterTemplate") is CPUParticles2D)
	assert_true((cut.get_node("EmitterTemplate") as CPUParticles2D).one_shot)
	assert_true(chop.get_node("EmitterTemplate") is CPUParticles2D)
	assert_true((chop.get_node("EmitterTemplate") as CPUParticles2D).one_shot)
	assert_true(mine.get_node("EmitterTemplate") is CPUParticles2D)
	assert_true((mine.get_node("EmitterTemplate") as CPUParticles2D).one_shot)
	assert_true(rain.get_node("Rain") is CPUParticles2D)
	assert_true(rain.get_node("Ripples") is CPUParticles2D)
	var rain_particles := rain.get_node("Rain") as CPUParticles2D
	var ripple_particles := rain.get_node("Ripples") as CPUParticles2D
	assert_true(rain_particles.z_index > ripple_particles.z_index)
	assert_equal(ripple_particles.emission_shape, CPUParticles2D.EMISSION_SHAPE_RECTANGLE)
	assert_equal(ripple_particles.initial_velocity_min, 0.0)
	assert_equal(ripple_particles.initial_velocity_max, 0.0)
	assert_true(ripple_particles.randomness >= 0.9)
	cut.free()
	chop.free()
	mine.free()
	rain.free()


func test_presentation_layout_uses_shared_theme_and_safe_fixed_panels() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var inventory := (load("res://scenes/ui/inventory_interface.tscn") as PackedScene).instantiate() as InventoryUI
	var inventory_slot := (load("res://scenes/ui/inventory_slot.tscn") as PackedScene).instantiate() as ColorRect
	assert_true(inventory_slot.get_node("Icon") is TextureRect)
	assert_true(inventory_slot.get_node("Amount") is Label)
	assert_true(inventory_slot.get_node_or_null("Label") == null)
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
	assert_true(status.get_node("Panel/WeatherIcon") is TextureRect)
	assert_true(status.get_node("Panel/HandIcon") is TextureRect)
	assert_true((status.get_node("Panel/WeatherIcon") as TextureRect).texture != null)
	var original_source := GameManager.player.active_hand_source
	var original_toolbar_index := GameManager.player.backpack_state.selected_toolbar_index
	assert_equal(GameManager.player.select_bar_index(PlayerState.ActiveHandSource.TOOLBAR, 0), OK)
	status._refresh()
	assert_equal(
		(status.get_node("Panel/HandIcon") as TextureRect).texture,
		DataCatalog.get_item(&"tool_hoe").icon_texture
	)
	assert_equal(
		(status.get_node("Panel/Hand") as Label).text,
		DataCatalog.get_item(&"tool_hoe").display_name
	)
	assert_true(not (status.get_node("Panel/Hand") as Label).text.contains("TOOLS"))
	assert_true(not (status.get_node("Panel/Hand") as Label).text.contains("ITEMS"))
	var player := (load("res://scenes/actors/player/player.tscn") as PackedScene).instantiate() as FarmPlayer
	root.add_child(player)
	assert_equal(player.bind_state(GameManager.player), OK)
	player._show_selection_popup(PlayerState.ActiveHandSource.TOOLBAR)
	assert_true(player.get_node_or_null("SelectionPopup/Background") == null)
	assert_equal(player.selection_slots.get_child_count(), GameManager.player.backpack_state.capacity(&"toolbar"))
	var selected_icon := player.selection_slots.get_child(0).get_node("Icon") as TextureRect
	var unselected_icon := player.selection_slots.get_child(1).get_node("Icon") as TextureRect
	assert_equal(selected_icon.texture, DataCatalog.get_item(&"tool_hoe").icon_texture)
	assert_equal(selected_icon.scale, Vector2(1.35, 1.35))
	assert_equal(unselected_icon.scale, Vector2.ONE)
	GameManager.player.backpack_state.selected_toolbar_index = original_toolbar_index
	GameManager.player.active_hand_source = original_source
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
	inventory_slot.free()
	presentation.free()
	player.free()
	status.free()


func test_calendar_manager_samples_time_directly_and_keeps_interior_more_neutral() -> void:
	var manager := CalendarManagerService.new()
	var morning := manager.sampled_light_color(6, 0)
	var noon := manager.sampled_light_color(12, 0)
	var evening := manager.sampled_light_color(18, 0)
	var night := manager.sampled_light_color(23, 0)
	assert_true(morning != noon)
	assert_true(noon != evening)
	assert_true(evening != night)
	assert_equal(night, manager.config.night_color)
	var interior_night := manager.sampled_light_color(23, 0, true)
	assert_true(interior_night.get_luminance() > night.get_luminance())
	manager.free()
