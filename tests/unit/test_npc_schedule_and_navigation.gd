extends ProjectTestCase


func test_schedule_filters_by_date_and_exposes_wander_configuration() -> void:
	var schedule := NpcSchedule.new()
	schedule.id = &"test_schedule"
	schedule.map_id = &"farm"
	schedule.target_position = Vector2(100, 80)
	schedule.wander_zone = Vector2(4, 3)
	schedule.wander_interval = 10.0
	schedule.seasons = [SeasonMeta.SeasonType.SPRING]
	assert_true(schedule.matches_date(SeasonMeta.SeasonType.SPRING, 1, 1))
	assert_true(not schedule.matches_date(SeasonMeta.SeasonType.SUMMER, 1, 1))
	assert_equal(schedule.wander_zone, Vector2(4, 3))
	assert_equal(schedule.wander_interval, 10.0)


func test_npc_scene_uses_native_navigation_agent() -> void:
	var scene := load("res://scenes/actors/npcs/npc.tscn") as PackedScene
	var npc := scene.instantiate() as FarmNpc
	assert_true(npc.get_node_or_null("NavigationAgent2D") is NavigationAgent2D)
	npc.free()
