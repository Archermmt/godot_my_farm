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
	assert_true(not player.has_node("Hands"))
	var charge_bar := player.get_node("ChargeBar") as ProgressBar
	assert_true(charge_bar != null)
	assert_true(not charge_bar.visible)
	assert_true(not charge_bar.show_percentage)
	assert_true(player.get_node("SelectionPopup") is Control)
	assert_true(player.get_node("SelectionTimer") is Timer)
	assert_true(player.get_node("InteractionOrigin") is Marker2D)
	assert_equal(player.pickup_radius, 72.0)
	assert_equal(player.pickup_collect_distance, 10.0)
	assert_equal(player.pickup_delay_for(&"drop"), 1.0)
	assert_equal(player.pickup_delay_for(&"harvestable"), 0.5)
	assert_equal(player.pickup_delay_for(&"generate"), 0.0)
	assert_true(player.pickup_speed_curve != null)
	assert_true(not player.has_node("PickupRange"))
	assert_true(not player.has_node("CollectArea"))
	var effect_area := player.get_node("EffectArea") as EffectArea
	assert_true(effect_area != null)
	assert_true(effect_area.top_level)
	player.position = Vector2(100, 100)
	assert_equal(effect_area.global_position, Vector2.ZERO)
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
	assert_true((main.get_node("World") as Node2D).y_sort_enabled)
	assert_true((main.get_node("World/MapHost") as Node2D).y_sort_enabled)
	assert_true(actor_host.y_sort_enabled)
	assert_equal(actor_host.get_child_count(), 1)
	assert_true(actor_host.get_child(0) is FarmPlayer)
	assert_true(actor_host.get_child(0).is_in_group("player"))
	var inventory_ui := main.get_node("UILayer/InventoryInterface") as InventoryUI
	assert_true(inventory_ui != null)
	assert_true(inventory_ui.get_node("InventoryPanel/ToolbarSlots") is HBoxContainer)
	assert_true(inventory_ui.get_node("InventoryPanel/ItembarSlots") is HBoxContainer)
	assert_true(inventory_ui.get_node("InventoryPanel/InventorySlots") is GridContainer)
	assert_true(main.get_node("UILayer/PresentationLayer") is PresentationController)
	main.free()


func test_player_charge_bar_tracks_level_color_and_cancel_lifecycle() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as FarmPlayer
	scene_tree.root.add_child(player)
	var map := BaseMap.new()
	map.cells[Vector2i(0, 1)] = MapCell.new(Vector2i(0, 1), CellState.CellFlag.BASE)
	var player_state := PlayerState.new()
	player_state.cell = Vector2i.ZERO
	player_state.facing = &"down"
	player_state.energy = 10
	var backpack_state := BackpackState.new()
	backpack_state.set_slot(&"toolbar", 0, BackpackSlot.new(&"toolbar_0", &"axe", 1))
	backpack_state.active_hand_source = BackpackState.ActiveHandSource.TOOLBAR
	assert_equal(player.setup(player_state), OK)
	assert_equal(player.backpack.setup(backpack_state), OK)
	var tool_meta := DataCatalog.get_item(&"axe") as ToolMeta
	var tool := Tool.new(tool_meta)
	assert_equal(player.effect_area.begin(player_state, backpack_state, map, tool), OK)
	player._refresh_charge_bar()
	assert_true(player.charge_bar.visible)
	assert_equal(player.charge_bar.max_value, 1.0)
	assert_equal(player.charge_bar.value, 0.0)
	assert_equal(player._charge_fill_style.bg_color, FarmPlayer.CHARGE_COLOR_LOW)
	player.effect_area.update(0.1)
	player._refresh_charge_bar()
	assert_true(player.charge_bar.value > 0.0)
	assert_true(player._charge_fill_style.bg_color != FarmPlayer.CHARGE_COLOR_LOW)
	player.effect_area.update(0.3)
	player._refresh_charge_bar()
	assert_equal(player.effect_area.charge_level, 1)
	assert_true(is_equal_approx(player.charge_bar.value, 0.8))
	assert_true(player.charge_bar.value > 0.0)
	assert_true(player._charge_fill_style.bg_color != FarmPlayer.CHARGE_COLOR_LOW)
	assert_true(player._charge_fill_style.bg_color != FarmPlayer.CHARGE_COLOR_HIGH)
	player._cancel_interaction()
	assert_true(not player.charge_bar.visible)
	assert_equal(player.charge_bar.value, 0.0)
	tool.free()
	map.free()
	player.free()
