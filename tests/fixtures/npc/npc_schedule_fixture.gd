extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load("res://scenes/app/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _frame: int in 8:
		await process_frame
	if MapManager.current_map_id() != &"farm" or not _assert_current_npcs([&"npc_villager"]):
		_fail("initial farm NPC set is invalid")
		return

	GameManager.calendar.hour = 11
	GameManager.calendar.minute = 59
	if GameManager.advance_minutes(1) != OK:
		_fail("failed to advance to noon schedule")
		return
	await process_frame
	if GameManager.get_npc(&"npc_villager").map_id != &"field" or GameManager.get_npc(&"npc_fisher").map_id != &"farm":
		_fail("noon cross-map schedule did not update global NPC states")
		return
	if not _assert_current_npcs([&"npc_fisher"]):
		_fail("farm did not replace villager with fisher at noon")
		return

	MapManager.config = MapManager.config.duplicate() as AutoloadConfig
	MapManager.config.transition_duration = 0.0
	for index: int in 20:
		var target_map: StringName = &"field" if index % 2 == 0 else &"farm"
		var spawn_id: StringName = &"from_farm" if target_map == &"field" else &"from_field"
		if MapManager.request_map_change(target_map, spawn_id) != OK:
			_fail("map change request %d failed" % index)
			return
		if not await _wait_transition():
			_fail("map change %d timed out" % index)
			return
		var expected: Array[StringName] = [&"npc_villager"] if target_map == &"field" else [&"npc_fisher"]
		if not _assert_current_npcs(expected):
			_fail("map change %d created wrong or duplicate NPC actors" % index)
			return

	for _day: int in 2:
		GameManager._complete_day()
		await process_frame
	if GameManager.npcs.size() != 2 or not _assert_current_npcs([&"npc_villager"]):
		_fail("two day advances changed NPC uniqueness or current farm actors")
		return
	print("[NpcScheduleFixture] PASS | npcs=2 | map_round_trips=20 | day_advances=2")
	main.queue_free()
	await process_frame
	quit(0)


func _wait_transition() -> bool:
	for _frame: int in 180:
		await process_frame
		if not MapManager.is_transitioning():
			return true
	return false


func _assert_current_npcs(expected_ids: Array[StringName]) -> bool:
	if MapManager.npc_actor_count() != expected_ids.size():
		return false
	var nodes := get_nodes_in_group("npc")
	if nodes.size() != expected_ids.size():
		return false
	var seen: Dictionary[StringName, bool] = {}
	for node: Node in nodes:
		var actor := node as FarmNpc
		if actor == null or actor.state == null or actor.state.npc_id not in expected_ids or seen.has(actor.state.npc_id):
			return false
		seen[actor.state.npc_id] = true
	return true


func _fail(message: String) -> void:
	push_error("[NpcScheduleFixture] %s" % message)
	quit(1)
