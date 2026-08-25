extends ProjectTestCase


func test_gameplay_selection_and_inventory_actions_are_keyboard_only() -> void:
	for action: StringName in [
		&"use_held",
		&"drop",
		&"drop_held",
		&"toolbar_previous",
		&"toolbar_next",
		&"itembar_previous",
		&"itembar_next",
		&"inventory_toggle",
		&"inventory_swap",
		&"inventory_confirm",
	]:
		assert_true(InputMap.has_action(action), "missing InputMap action: %s" % action)
		for event: InputEvent in InputMap.action_get_events(action):
			assert_true(event is InputEventKey, "%s contains non-keyboard input" % action)
	for removed_action: StringName in [&"primary_action", &"secondary_action", &"hotbar_1", &"hotbar_10"]:
		assert_true(not InputMap.has_action(removed_action), "legacy input action still registered: %s" % removed_action)


func test_input_direction_stays_continuous_and_normalized() -> void:
	var diagonal := FarmPlayer.normalized_direction(Vector2(1.0, 1.0))
	assert_true(is_equal_approx(diagonal.length(), 1.0))
	assert_true(is_equal_approx(diagonal.x, diagonal.y))
	assert_equal(FarmPlayer.normalized_direction(Vector2.ZERO), Vector2.ZERO)
	var player := FarmPlayer.new()
	var velocity := player.velocity_for(Vector2(0.8, 0.4), false)
	assert_true(is_equal_approx(velocity.length(), player.run_speed))
	assert_true(not is_zero_approx(velocity.x))
	assert_true(not is_zero_approx(velocity.y))
	player.free()


func test_facing_uses_horizontal_priority_and_stays_stable_when_stopped() -> void:
	assert_equal(FarmPlayer.resolve_facing(Vector2(1.0, 1.0), &"up"), &"right")
	assert_equal(FarmPlayer.resolve_facing(Vector2(-1.0, 1.0), &"up"), &"left")
	assert_equal(FarmPlayer.resolve_facing(Vector2(0.0, -1.0), &"right"), &"up")
	assert_equal(FarmPlayer.resolve_facing(Vector2(0.0, 1.0), &"left"), &"down")
	assert_equal(FarmPlayer.resolve_facing(Vector2.ZERO, &"left"), &"left")


func test_two_input_locks_must_both_be_released() -> void:
	var player := FarmPlayer.new()
	assert_equal(player.lock_input(&"inventory"), OK)
	assert_equal(player.lock_input(&"scene_transition"), OK)
	assert_true(player.is_input_locked())
	assert_equal(player.unlock_input(&"inventory"), OK)
	assert_true(player.is_input_locked())
	assert_equal(player.unlock_input(&"scene_transition"), OK)
	assert_true(not player.is_input_locked())
	assert_equal(player.unlock_input(&"scene_transition"), ERR_DOES_NOT_EXIST)
	player.free()


func test_walk_speed_is_lower_and_zero_input_stops() -> void:
	var player := FarmPlayer.new()
	assert_true(player.walk_speed < player.run_speed)
	assert_equal(player.velocity_for(Vector2.ZERO, false), Vector2.ZERO)
	assert_true(is_equal_approx(player.velocity_for(Vector2.RIGHT, false).length(), player.run_speed))
	assert_true(is_equal_approx(player.velocity_for(Vector2.RIGHT, true).length(), player.walk_speed))
	assert_true(is_equal_approx(player.velocity_for(Vector2(1, 1), false).length(), player.run_speed))
	player.free()


func test_motion_state_and_animation_names_are_deterministic() -> void:
	assert_equal(FarmPlayer.resolve_motion_state(Vector2.ZERO, false), &"idle")
	assert_equal(FarmPlayer.resolve_motion_state(Vector2.RIGHT, true), &"walk")
	assert_equal(FarmPlayer.resolve_motion_state(Vector2.RIGHT, false), &"run")
	var player := FarmPlayer.new()
	player.set_motion(&"idle", &"down")
	assert_equal(FarmPlayer.animation_name_for(player.motion_state, player.facing), &"idle_down")
	player.set_motion(&"walk", &"left")
	assert_equal(FarmPlayer.animation_name_for(player.motion_state, player.facing), &"walk_left")
	player.set_motion(&"run", &"up")
	assert_equal(FarmPlayer.animation_name_for(player.motion_state, player.facing), &"run_up")
	assert_equal(FarmPlayer.animation_name_for(&"invalid", &"invalid"), &"idle_down")
	player.free()
