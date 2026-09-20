extends ProjectTestCase


func test_player_scene_uses_single_runtime_controller() -> void:
	var packed := load("res://scenes/actors/player/player.tscn") as PackedScene
	var player := packed.instantiate() as FarmPlayer
	assert_true(player != null)
	assert_true(player.is_in_group("player"))
	assert_true(player.get_node_or_null("AnimationPlayer") is AnimationPlayer)
	assert_true(player.get_node_or_null("Backpack") is PlayerBackpack)
	assert_true(not player.has_node("PlayerInput"))
	player.free()


func test_main_scene_contains_one_player_host() -> void:
	var main := (load("res://scenes/app/main.tscn") as PackedScene).instantiate()
	var actor_host := main.get_node("World/ActorHost") as Node2D
	assert_equal(actor_host.get_child_count(), 1)
	assert_true(actor_host.get_child(0) is FarmPlayer)
	main.free()
