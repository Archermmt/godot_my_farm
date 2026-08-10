extends ProjectTestCase

const EXPECTED_AUTOLOAD_ORDER: Array[String] = [
	"EventBus",
	"DataCatalog",
	"GameManager",
		"SceneManager",
		"AudioManager",
]


func test_game_services_start_in_architecture_order() -> void:
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	var root_names: Array[String] = []
	for child: Node in scene_tree.root.get_children():
		root_names.append(child.name)
	var previous_index: int = -1
	for autoload_name: String in EXPECTED_AUTOLOAD_ORDER:
		var current_index: int = root_names.find(autoload_name)
		assert_true(current_index >= 0, "Missing autoload %s" % autoload_name)
		assert_true(current_index > previous_index, "Autoload %s is out of order" % autoload_name)
		previous_index = current_index


func test_autoload_catalog_and_new_game_are_ready() -> void:
	assert_true(DataCatalog.is_ready_for_game())
	assert_equal((DataCatalog.get_item(&"tool_hoe") as ToolMeta).tool_kind, ToolMeta.ToolKind.HOE)
	assert_true(GameManager.is_initialized())
	assert_equal(GameManager.player.map_id, &"cabin")
	assert_equal(GameManager.player.itembar.count_item(&"seed_parsnip"), 15)
	assert_equal(GameManager.player.toolbar.count_item(&"tool_hoe"), 1)
	assert_equal(GameManager.used_inventory_slots(), 0)
	assert_true(GameManager.can_snapshot())
