extends ProjectTestCase

const PLAYER_SCENE_PATH := "res://scenes/actors/player/player.tscn"
const MAIN_SCENE_PATH := "res://scenes/app/main.tscn"


func test_player_leaf_scene_uses_one_root_controller() -> void:
	var packed: PackedScene = load(PLAYER_SCENE_PATH) as PackedScene
	var player: FarmPlayer = packed.instantiate() as FarmPlayer
	assert_true(player != null)
	assert_true(player.is_in_group("player"))
	assert_true(player.get_node("CollisionShape2D") is CollisionShape2D)
	assert_true(player.get_node("Visual") is Node2D)
	assert_true(player.get_node("Visual").get_script() == null)
	assert_true(not player.has_node("PlayerInput"))
	assert_true(not player.has_node("PlayerMotor"))
	assert_true(player.get_node("AnimationPlayer") is AnimationPlayer)
	assert_true(player.get_node("Visual/Sprite") is Sprite2D)
	assert_true(player.get_node("Hands") is Node2D)
	assert_true(player.get_node("Hands/HeldVisual") is Node2D)
	assert_true(player.get_node("SelectionPopup") is Control)
	assert_true(player.get_node("SelectionTimer") is Timer)
	assert_true(player.get_node("InteractionOrigin") is Marker2D)
	var interaction_cursor := player.get_node("InteractionCursor") as InteractionCursor
	assert_true(interaction_cursor != null)
	assert_true(interaction_cursor.top_level)
	player.position = Vector2(100, 100)
	assert_equal(interaction_cursor.global_position, Vector2.ZERO)
	var camera: Camera2D = player.get_node("Camera2D") as Camera2D
	assert_true(camera.enabled)
	assert_equal(camera.process_callback, Camera2D.CAMERA2D_PROCESS_PHYSICS)
	var sprite: Sprite2D = player.get_node("Visual/Sprite") as Sprite2D
	assert_equal(sprite.hframes, 6)
	assert_equal(sprite.vframes, 4)
	assert_true(sprite.texture != null)
	var animation_player: AnimationPlayer = player.get_node("AnimationPlayer") as AnimationPlayer
	var animation_library: AnimationLibrary = animation_player.get_animation_library("")
	assert_true(animation_library != null)
	assert_equal(animation_library.get_animation_list().size(), 12)
	assert_true(animation_library.has_animation("idle_down"))
	assert_true(animation_library.has_animation("walk_left"))
	assert_true(animation_library.has_animation("run_up"))
	player.free()


func test_main_actor_host_contains_exactly_one_player() -> void:
	var packed: PackedScene = load(MAIN_SCENE_PATH) as PackedScene
	var main: Node = packed.instantiate()
	var actor_host: Node2D = main.get_node("World/ActorHost") as Node2D
	assert_equal(actor_host.get_child_count(), 1)
	assert_true(actor_host.get_child(0) is FarmPlayer)
	assert_true(actor_host.get_child(0).is_in_group("player"))
	var inventory_ui := main.get_node("UILayer/InventoryInterface") as InventoryUI
	assert_true(inventory_ui != null)
	assert_true(inventory_ui.get_node("InventoryPanel/ToolbarSlots") is HBoxContainer)
	assert_true(inventory_ui.get_node("InventoryPanel/ItembarSlots") is HBoxContainer)
	assert_true(inventory_ui.get_node("InventoryPanel/InventorySlots") is GridContainer)
	main.free()
