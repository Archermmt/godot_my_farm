extends ProjectTestCase


func test_item_tool_area_is_hidden_after_cancel() -> void:
	var scene := load("res://scenes/items/tools/item_tool.tscn") as PackedScene
	var tool := scene.instantiate() as ItemTool
	(Engine.get_main_loop() as SceneTree).root.add_child(tool)
	await (Engine.get_main_loop() as SceneTree).process_frame
	var area := tool.get_node("ToolArea") as Area2D
	var shape := tool.get_node("ToolArea/CollisionShape2D") as CollisionShape2D
	tool.meta = DataCatalog.get_item(&"sickle")
	assert_equal(tool.begin_charge(), OK)
	assert_true(area.visible)
	assert_true(not shape.disabled)
	tool.cancel_charge()
	assert_true(not area.visible)
	assert_true(shape.disabled)
	tool.queue_free()


func test_cell_tool_scene_contains_no_item_tool_area() -> void:
	var scene := load("res://scenes/items/tools/cell_tool.tscn") as PackedScene
	var tool := scene.instantiate() as CellTool
	assert_true(tool != null)
	assert_true(tool.get_node_or_null("ToolArea") == null)
	tool.free()
