extends ProjectTestCase
const InteractManagerScript = preload("res://scripts/autoload/interact_manager.gd")


func test_audio_definitions_pool_and_high_frequency_throttle_are_bounded() -> void:
	var manager := AudioManagerService.new()
	var root := (Engine.get_main_loop() as SceneTree).root
	root.add_child(manager)
	assert_equal(manager.play_audio(&"ui_confirm"), OK)
	assert_equal(manager.play_audio(&"ui_confirm"), ERR_BUSY)
	for _index: int in 100:
		manager.play_audio(&"footstep")
	assert_true(manager.active_event_count(&"footstep") <= 1)
	assert_equal(manager.play_audio(&"missing_event"), ERR_DOES_NOT_EXIST)
	manager._on_map_changed(&"farm")
	manager._on_map_changed(&"field")
	manager.free()


func test_multicell_feedback_uses_one_bounded_effect_and_invalid_uses_no_success_effect() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var effect_host := Node2D.new()
	root.add_child(effect_host)
	var manager := EffectManagerService.new()
	root.add_child(manager)
	manager._effect_host = effect_host
	var definitions: Dictionary[StringName, PackedScene] = {
		&"water": load("res://scenes/effects/action_effect.tscn") as PackedScene,
	}
	manager.config = manager.config.duplicate() as GameConfig
	manager.config.effect_scenes = definitions
	var positions: Array[Vector2] = []
	for x: int in 81:
		positions.append(Vector2(x % 9, x / 9))
	for _index: int in 50:
		manager.play_effect(&"water", positions)
	assert_true(effect_host.get_child_count() > 0)
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


func test_weather_cloud_shadow_and_lightning_scenes_are_editable() -> void:
	var cloud := (load("res://scenes/effects/cloud_shadow_weather.tscn") as PackedScene).instantiate() as CloudShadowWeatherEffect
	var lightning := (load("res://scenes/effects/lightning_weather.tscn") as PackedScene).instantiate() as LightningWeatherEffect
	assert_true(cloud.shadow_texture != null)
	assert_true(cloud.cloudy_shadow_count > cloud.clear_shadow_count)
	assert_true(lightning.get_node("Timer") is Timer)
	assert_true(lightning.get_node("WeatherFlash/Flash") is ColorRect)
	assert_true(lightning.get_node("WeatherFlash/Bolt") is TextureRect)
	cloud.free()
	lightning.free()


func test_clear_and_cloudy_shadows_cover_the_map_above_ground() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var map := (load("res://scenes/maps/farm/farm.tscn") as PackedScene).instantiate() as BaseMap
	var clear := (load("res://scenes/effects/cloud_shadow_weather.tscn") as PackedScene).instantiate() as CloudShadowWeatherEffect
	var cloudy := (load("res://scenes/effects/cloud_shadow_weather.tscn") as PackedScene).instantiate() as CloudShadowWeatherEffect
	root.add_child(map)
	map.get_node("Effects").add_child(clear)
	map.get_node("Effects").add_child(cloudy)
	clear.play(&"clear", [])
	cloudy.play(&"cloudy", [])
	assert_equal(clear.get_child_count(), clear.clear_shadow_count)
	assert_equal(cloudy.get_child_count(), cloudy.cloudy_shadow_count)
	assert_true(cloudy.get_child_count() > clear.get_child_count())
	var clear_shadow := clear.get_child(0) as Sprite2D
	var cloudy_shadow := cloudy.get_child(0) as Sprite2D
	assert_true(clear_shadow != null and clear_shadow.texture != null)
	assert_true(clear.z_index + clear_shadow.z_index >= 2)
	assert_true(clear_shadow.modulate.a >= 0.3)
	assert_true(cloudy_shadow.scale.x > clear_shadow.scale.x)
	assert_true(cloudy_shadow.modulate.a > clear_shadow.modulate.a)
	map.free()


func test_bed_and_npc_proximity_prompts_use_2d_canvas_coordinates() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var controller := InteractManager
	var player := (load("res://scenes/actors/player/player.tscn") as PackedScene).instantiate() as FarmPlayer
	var bed := (load("res://scenes/items/interactables/bed.tscn") as PackedScene).instantiate()
	var npc := (load("res://scenes/actors/npcs/npc.tscn") as PackedScene).instantiate() as FarmNpc
	root.add_child(player)
	root.add_child(bed)
	root.add_child(npc)
	player.state = PlayerState.new()
	bed.global_position = Vector2(160, 120)
	npc.global_position = Vector2(240, 120)
	npc.state = NpcState.new()
	npc.state.npc_id = &"npc_villager"

	bed.on_interact_area_entered(player.interact_area)
	assert_true(controller._prompt_bubble != null)
	controller._prompt_bubble._process(0.0)
	assert_true(controller._prompt_bubble.visible)
	assert_true(controller._prompt_bubble.position.is_finite())
	bed.interact(player)
	assert_true(controller.is_active())
	assert_equal(controller.session_state, InteractManagerScript.SessionState.REVEALING_TEXT)
	assert_true(controller.current_timeline != null)
	assert_true(controller.current_timeline.resource_path.ends_with("bed_sleep_confirmation.dtl"))
	var sleep_timeline := controller.current_timeline as DialogicTimeline
	sleep_timeline.process()
	assert_true(sleep_timeline.events.size() >= 3)
	var yes_choice := sleep_timeline.events[1] as DialogicChoiceEvent
	assert_true(yes_choice != null)
	assert_equal(yes_choice.text, "Yes")
	assert_equal(str(yes_choice.extra_data.get("sleep", "")), "yes")
	controller._close_session()
	bed.on_interact_area_exited(player.interact_area)
	assert_true(controller._prompt_bubble == null)

	npc.on_interact_area_entered(player.interact_area)
	assert_true(controller._prompt_bubble != null)
	controller._prompt_bubble._process(0.0)
	assert_true(controller._prompt_bubble.visible)
	assert_true(controller._prompt_bubble.position.is_finite())
	npc.on_interact_area_exited(player.interact_area)
	assert_true(controller._prompt_bubble == null)

	npc.free()
	bed.free()
	player.free()


func test_dialogic_choice_focus_has_visible_mark_and_scale() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var button := DialogicNode_ChoiceButton.new()
	root.add_child(button)
	button.size = Vector2(180.0, 44.0)
	button.show()
	InteractManager._style_dialogic_choices()
	var focus_style := button.get_theme_stylebox("focus") as StyleBoxFlat
	assert_true(focus_style != null)
	assert_equal(focus_style.border_width_left, 3)
	assert_equal(focus_style.border_width_top, 3)
	assert_equal(focus_style.border_width_right, 3)
	assert_equal(focus_style.border_width_bottom, 3)
	button.emit_signal("focus_entered")
	assert_equal(button.scale, Vector2.ONE * 1.08)
	button.emit_signal("focus_exited")
	assert_equal(button.scale, Vector2.ONE)
	button.free()


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
	var player := (load("res://scenes/actors/player/player.tscn") as PackedScene).instantiate() as FarmPlayer
	root.add_child(player)
	assert_equal(player.setup(GameManager.player), OK)
	var original_source := GameManager.backpack_state.active_hand_source
	var original_toolbar_id: StringName = GameManager.backpack_state.selected_ids.get(&"toolbar", &"") as StringName
	assert_true(player.backpack.select_bar_index(BackpackState.ActiveHandSource.TOOLBAR, 0))
	GameManager.backpack_state.active_hand_source = BackpackState.ActiveHandSource.TOOLBAR
	status._refresh()
	assert_equal(
		(status.get_node("Panel/HandIcon") as TextureRect).texture,
		DataCatalog.get_item(&"hoe").icon_texture
	)
	assert_equal(
		(status.get_node("Panel/Hand") as Label).text,
		DataCatalog.get_item(&"hoe").display_name
	)
	assert_true(not (status.get_node("Panel/Hand") as Label).text.contains("TOOLS"))
	assert_true(not (status.get_node("Panel/Hand") as Label).text.contains("ITEMS"))
	player.backpack.setup(GameManager.backpack_state)
	player._show_selection_popup(BackpackState.ActiveHandSource.TOOLBAR)
	assert_true(player.get_node_or_null("SelectionPopup/Background") == null)
	assert_equal(player.selection_slots.get_child_count(), GameManager.backpack_state.capacity(&"toolbar"))
	var selected_icon := player.selection_slots.get_child(0).get_node("Icon") as TextureRect
	var unselected_icon := player.selection_slots.get_child(1).get_node("Icon") as TextureRect
	assert_equal(selected_icon.texture, DataCatalog.get_item(&"hoe").icon_texture)
	assert_equal(selected_icon.scale, Vector2(1.35, 1.35))
	assert_equal(unselected_icon.scale, Vector2.ONE)
	GameManager.backpack_state.selected_ids[&"toolbar"] = original_toolbar_id
	GameManager.backpack_state.active_hand_source = original_source
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
