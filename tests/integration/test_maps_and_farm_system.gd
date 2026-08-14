extends ProjectTestCase

const MAP_PATHS := {
	&"farm": "res://scenes/maps/farm/farm.tscn",
	&"field": "res://scenes/maps/field/field.tscn",
	&"cabin": "res://scenes/maps/cabin/cabin.tscn",
}

func test_all_maps_have_aligned_layers_and_spawn_points() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	for map_id: StringName in [&"cabin", &"farm", &"field"]:
		var packed := load(MAP_PATHS[map_id]) as PackedScene
		assert_true(packed != null)
		var map := packed.instantiate() as BaseMap
		scene_tree.root.add_child(map)
		assert_equal(map.map_id, map_id)
		assert_equal(map.validate_alignment(), OK)
		assert_true(not map.coordinate_layer().get_used_cells().is_empty())
		assert_equal(map.cell_flags[map.coordinate_layer()], CellState.CellFlag.BASE)
		assert_equal(map.get_map_size(), map.coordinate_layer().get_used_rect().size)
		assert_equal(map.get_tile_size(), map.coordinate_layer().tile_set.tile_size)
		assert_true(map.spawn_position(&"default") != Vector2.ZERO)
		assert_true(not map.has_node("InteractionCursor"))
		map.free()

func test_static_tile_cells_are_serialized_in_map_scenes() -> void:
	for map_id: StringName in [&"cabin", &"farm", &"field"]:
		var source := FileAccess.get_file_as_string(MAP_PATHS[map_id])
		assert_true(source.contains("tile_map_data = PackedByteArray"), "%s has no authored TileMap cells" % map_id)

func test_flag_layers_apply_flags_to_every_authored_cell() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	for map_id: StringName in [&"cabin", &"farm", &"field"]:
		var map := (load(MAP_PATHS[map_id]) as PackedScene).instantiate() as BaseMap
		scene_tree.root.add_child(map)
		assert_true(not map.cell_flags.is_empty())
		for layer: TileMapLayer in map.cell_flags:
			var flag: CellState.CellFlag = map.cell_flags[layer]
			assert_true(not layer.get_used_cells().is_empty(), "%s/%s flag layer is empty" % [map_id, layer.name])
			for coordinates: Vector2i in layer.get_used_cells():
				assert_true(map.get_cell(coordinates).has_static_flag(flag), "%s/%s did not apply flag at %s" % [map_id, layer.name, coordinates])
		map.free()

func test_farm_coordinate_round_trip_and_cell_flags() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	var map := (load(MAP_PATHS[&"farm"]) as PackedScene).instantiate() as BaseMap
	scene_tree.root.add_child(map)
	var farm := map
	for cell: Vector2i in [Vector2i(2, 2), Vector2i(8, 10), Vector2i(15, 10), Vector2i(24, 16)]:
		var world := farm.cell_to_world_center(cell)
		assert_equal(farm.world_to_cell(world), cell)
	var map_size := farm.get_map_size()
	assert_equal(farm.cells.size(), map_size.x * map_size.y)
	assert_true(farm.get_cell(Vector2i(8, 10)).has_static_flag(CellState.CellFlag.DIGGABLE))
	assert_true(farm.get_cell(Vector2i(8, 10)).has_static_flag(CellState.CellFlag.DROPABLE))
	assert_true(farm.get_cell(Vector2i(15, 10)).has_static_flag(CellState.CellFlag.ROAD))
	assert_true(farm.get_cell(Vector2i(24, 16)).has_static_flag(CellState.CellFlag.BLOCKED))
	assert_true(not farm.is_walkable(Vector2i(24, 16)))
	assert_equal(farm.get_cells_in_rect(Rect2i(3, 8, 2, 2)).size(), 4)
	map.free()


func test_farm_diggable_ground_uses_a_distinct_visible_tile() -> void:
	var farm := (load(MAP_PATHS[&"farm"]) as PackedScene).instantiate() as BaseMap
	var layer := farm.get_node("TileMaps/DiggableLayer") as TileMapLayer
	assert_true(layer.visible)
	for coordinates: Vector2i in layer.get_used_cells():
		assert_equal(layer.get_cell_source_id(coordinates), 0)
		assert_equal(layer.get_cell_atlas_coords(coordinates), Vector2i(4, 0))
	assert_equal(layer.get_cell_source_id(Vector2i.ZERO), -1)
	farm.free()

func test_dynamic_cell_state_is_not_tilemap_authority() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	var map := (load(MAP_PATHS[&"farm"]) as PackedScene).instantiate() as BaseMap
	scene_tree.root.add_child(map)
	var state: MapState = GameManager.maps[&"farm"]
	assert_true(map.configure_state(state) == OK)
	var map_cell := map.get_cell(Vector2i(5, 9))
	assert_equal(map_cell.use_tool(ToolMeta.ToolKind.HOE), OK)
	assert_equal(map_cell.use_tool(ToolMeta.ToolKind.WATERING_CAN), OK)
	assert_true(map_cell.has_state_flag(CellState.CellFlag.DUG))
	assert_true(map_cell.is_watered())
	map.free()


func test_tool_transaction_persists_and_rebuilds_farm_cell_projection() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	var farm := (load(MAP_PATHS[&"farm"]) as PackedScene).instantiate() as BaseMap
	scene_tree.root.add_child(farm)
	var map_state := MapState.new()
	map_state.map_id = &"farm"
	assert_equal(farm.configure_state(map_state), OK)
	var player_state := PlayerState.new()
	player_state.set_stamina(10)
	var coordinates := Vector2i(8, 10)
	var hoe_result := Tool.perform(DataCatalog.get_item(&"tool_hoe") as ToolMeta, farm, [coordinates], player_state.stamina) as CellToolOutcome
	assert_true(hoe_result.succeeded())
	assert_equal(hoe_result.projection_error, OK)
	player_state.set_stamina(player_state.stamina - hoe_result.stamina_spent)
	var water_result := Tool.perform(DataCatalog.get_item(&"tool_watering_can") as ToolMeta, farm, [coordinates], player_state.stamina) as CellToolOutcome
	assert_true(water_result.succeeded())
	assert_equal(water_result.projection_error, OK)
	assert_true(map_state.cells[coordinates].flags & CellState.CellFlag.DUG)
	assert_true(map_state.cells[coordinates].flags & CellState.CellFlag.WATERED)
	assert_true(farm.get_node_or_null("TileMaps/DugLayer") is TileMapLayer)
	assert_true(farm.get_node_or_null("TileMaps/WateredLayer") is TileMapLayer)

	var serialized := JSON.parse_string(JSON.stringify(map_state.to_dict())) as Dictionary
	var restored_state := MapState.from_dict(serialized)
	var restored_farm := (load(MAP_PATHS[&"farm"]) as PackedScene).instantiate() as BaseMap
	scene_tree.root.add_child(restored_farm)
	assert_equal(restored_farm.configure_state(restored_state), OK)
	assert_true(restored_farm.get_cell(coordinates).is_dug())
	assert_true(restored_farm.get_cell(coordinates).is_watered())
	assert_true(restored_farm.get_node_or_null("TileMaps/DugLayer") is TileMapLayer)
	restored_farm.free()
	farm.free()

func test_base_map_restores_and_operates_on_state_dtos() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	var farm := (load(MAP_PATHS[&"farm"]) as PackedScene).instantiate() as BaseMap
	scene_tree.root.add_child(farm)
	var first_state := MapState.new()
	first_state.map_id = &"farm"
	var persisted_cell := CellState.new()
	persisted_cell.cell = Vector2i(5, 9)
	persisted_cell.flags = CellState.CellFlag.DUG
	var persisted_item := PlantState.new()
	persisted_item.instance_id = &"crop_5_9"
	persisted_item.meta_id = &"crop_parsnip"
	persisted_item.cell = persisted_cell.cell
	persisted_cell.item_ids = [persisted_item.instance_id]
	first_state.cells[persisted_cell.cell] = persisted_cell
	first_state.items[persisted_item.instance_id] = persisted_item
	assert_equal(farm.configure_state(first_state), OK)
	assert_true(farm.get_cell(Vector2i(5, 9)).cell_state() == persisted_cell)
	assert_true(farm.get_cell(Vector2i(5, 9)).is_dug())
	assert_true(farm.items[&"crop_5_9"] is Plant)
	assert_true(farm.items[&"crop_5_9"].state == persisted_item)
	assert_true((farm.items[&"crop_5_9"] as Plant).plant_state() == persisted_item)
	assert_true((farm.items[&"crop_5_9"] as Plant).plant_meta() is PlantMeta)
	assert_true((farm.items[&"crop_5_9"] as Plant).plant_meta() == farm.items[&"crop_5_9"].meta)
	assert_equal(farm.move_item(persisted_item.instance_id, Vector2i(6, 9)), OK)
	assert_equal(persisted_item.cell, Vector2i(6, 9))
	assert_true(not farm.get_cell(Vector2i(5, 9)).has_item(persisted_item.instance_id))
	assert_true(farm.get_cell(Vector2i(6, 9)).has_item(persisted_item.instance_id))
	var replacement_state := MapState.new()
	replacement_state.map_id = &"farm"
	assert_equal(farm.configure_state(replacement_state), OK)
	assert_true(farm.get_cell(Vector2i(5, 9)).cell_state() != persisted_cell)
	assert_true(replacement_state.cells[Vector2i(5, 9)] == farm.get_cell(Vector2i(5, 9)).cell_state())
	assert_true(not farm.get_cell(Vector2i(5, 9)).is_dug())
	assert_true(farm.items.is_empty())
	farm.free()

func test_each_map_owns_a_distinct_tilemap_hierarchy() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	var farm := (load(MAP_PATHS[&"farm"]) as PackedScene).instantiate() as BaseMap
	var field := (load(MAP_PATHS[&"field"]) as PackedScene).instantiate() as BaseMap
	var cabin := (load(MAP_PATHS[&"cabin"]) as PackedScene).instantiate() as BaseMap
	scene_tree.root.add_child(farm)
	scene_tree.root.add_child(field)
	scene_tree.root.add_child(cabin)
	assert_true(farm.has_node("TileMaps/BaseLayer"))
	assert_true(farm.has_node("TileMaps/DugLayer"))
	assert_true(field.has_node("TileMaps/GroundLayer"))
	assert_true(field.has_node("TileMaps/ResourceLayer"))
	assert_true(cabin.has_node("TileMaps/FloorLayer"))
	assert_true(cabin.has_node("TileMaps/WallLayer"))
	for map: BaseMap in [farm, field, cabin]:
		var tilemaps := map.get_node("TileMaps") as Node2D
		assert_true(tilemaps != null)
		assert_equal(tilemaps.position, Vector2.ZERO)
		assert_equal(tilemaps.rotation, 0.0)
		assert_equal(tilemaps.scale, Vector2.ONE)
		assert_equal(map.managed_layers().size(), tilemaps.get_child_count())
		for layer: Node in tilemaps.get_children():
			assert_true(layer is TileMapLayer)
		for child: Node in map.get_children():
			assert_true(not child is TileMapLayer)
	assert_true(farm.get_node("MapItems") is Node2D)
	assert_true(field.get_node("MapItems") is Node2D)
	assert_true(farm.items_host == farm.get_node("MapItems/Items"))
	assert_true(farm.plants_host == farm.get_node("MapItems/Plants"))
	assert_true(farm.harvestables_host == farm.get_node("MapItems/Harvestables"))
	assert_true(field.plants_host == field.get_node("MapItems/Plants"))
	assert_true(field.harvestables_host == field.get_node("MapItems/Harvestables"))
	var farm_state := MapState.new()
	farm_state.map_id = &"farm"
	assert_equal(farm.configure_state(farm_state), OK)
	var plant_state := PlantState.new()
	plant_state.instance_id = &"crop_runtime_test"
	plant_state.meta_id = &"crop_parsnip"
	assert_equal(farm.add_item_state(plant_state, Vector2i(5, 9)), OK)
	var plant := farm.get_item(plant_state.instance_id)
	assert_true(plant.get_parent() == farm.get_node("MapItems/Plants"))
	assert_true(plant is Plant)
	assert_true((plant as Plant).plant_state() == plant_state)
	assert_equal(plant.item_id(), plant_state.instance_id)
	assert_equal(farm.item_count(), 1)
	farm.free()
	field.free()
	cabin.free()

func test_base_map_item_helpers_handle_missing_values() -> void:
	var base_map := BaseMap.new()
	assert_equal(base_map.add_item(null), ERR_INVALID_PARAMETER)
	var state := ItemState.new()
	state.instance_id = &"item_test"
	state.meta_id = &"material_wood"
	var item := Item.new()
	assert_equal(item.bind_state(state, DataCatalog.get_item(state.meta_id)), OK)
	assert_equal(base_map.add_item(item), ERR_UNCONFIGURED)
	assert_equal(base_map.item_count(), 0)
	item.free()
	base_map.free()


func test_base_map_rejects_meta_state_mismatch() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	var field := (load(MAP_PATHS[&"field"]) as PackedScene).instantiate() as BaseMap
	scene_tree.root.add_child(field)
	var map_state := MapState.new()
	map_state.map_id = &"field"
	assert_equal(field.configure_state(map_state), OK)
	var invalid_crop := ItemState.new()
	invalid_crop.instance_id = &"invalid_crop"
	invalid_crop.meta_id = &"crop_parsnip"
	assert_equal(field.add_item_state(invalid_crop, Vector2i(5, 9)), ERR_INVALID_PARAMETER)
	var harvestable := HarvestableState.new()
	harvestable.instance_id = &"tree_runtime"
	harvestable.meta_id = &"tree"
	assert_equal(field.add_item_state(harvestable, Vector2i(5, 9)), OK)
	var runtime_item := field.get_item(harvestable.instance_id)
	assert_true(runtime_item is Harvestable)
	assert_true((runtime_item as Harvestable).harvestable_state() == harvestable)
	assert_true((runtime_item as Harvestable).harvestable_meta() is HarvestableMeta)
	assert_true((runtime_item as Harvestable).harvestable_meta() == runtime_item.meta)
	field.free()
