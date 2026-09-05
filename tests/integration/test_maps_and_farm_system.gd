extends ProjectTestCase

const MAP_PATHS := {
	&"farm": "res://scenes/maps/farm/farm.tscn",
	&"field": "res://scenes/maps/field/field.tscn",
	&"beach": "res://scenes/maps/beach/beach.tscn",
}


func test_all_maps_have_aligned_layers_and_spawn_points() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	for map_id: StringName in [&"beach", &"farm", &"field"]:
		var packed := load(MAP_PATHS[map_id]) as PackedScene
		assert_true(packed != null)
		var map := packed.instantiate() as BaseMap
		scene_tree.root.add_child(map)
		assert_equal(map.map_id, map_id)
		assert_true(map.y_sort_enabled)
		assert_true((map.get_node("MapItems") as Node2D).y_sort_enabled)
		assert_true(map.item_hosts[ItemMeta.ItemType.MATERIAL].y_sort_enabled)
		assert_true(map.item_hosts[ItemMeta.ItemType.OBSTACLE].y_sort_enabled)
		assert_true(map.item_hosts[ItemMeta.ItemType.PLANT].y_sort_enabled)
		var base_layer := map.get_node("TileMaps/BaseLayer") as TileMapLayer
		var dug_layer := map.get_node("TileMaps/DugLayer") as TileMapLayer
		var watered_layer := map.get_node("TileMaps/WateredLayer") as TileMapLayer
		assert_equal(base_layer.z_index, 0)
		assert_equal(dug_layer.z_index, 1)
		assert_equal(watered_layer.z_index, 2)
		assert_equal(map.validate_alignment(), OK)
		var configured_base := map.map_layers[CellState.CellFlag.BASE]
		assert_true(not configured_base.get_used_cells().is_empty())
		assert_equal(map.get_map_size(), configured_base.get_used_rect().size)
		assert_equal(map.get_tile_size(), configured_base.tile_set.tile_size)
		assert_true(map.spawn_position(&"default") != Vector2.ZERO)
		assert_true(map.get_map_size().x >= 48)
		assert_true(map.get_map_size().y >= 32)
		assert_true(not map.has_node("InteractArea"))
		map.free()


func test_actor_host_renders_above_cell_state_layers() -> void:
	var main_scene := load("res://scenes/app/main.tscn") as PackedScene
	assert_true(main_scene != null)
	var main := main_scene.instantiate()
	var actor_host := main.get_node("World/ActorHost") as Node2D
	assert_equal(actor_host.z_index, 3)
	main.free()


func test_static_tile_cells_are_serialized_in_map_scenes() -> void:
	for map_id: StringName in [&"beach", &"farm", &"field"]:
		var source := FileAccess.get_file_as_string(MAP_PATHS[map_id])
		assert_true(source.contains("tile_map_data = PackedByteArray"), "%s has no authored TileMap cells" % map_id)


func test_flag_layers_apply_flags_to_every_authored_cell() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	for map_id: StringName in [&"beach", &"farm", &"field"]:
		var map := (load(MAP_PATHS[map_id]) as PackedScene).instantiate() as BaseMap
		scene_tree.root.add_child(map)
			assert_true(not map.map_layers.is_empty())
			for flag: CellState.CellFlag in map.map_layers:
				var layer: TileMapLayer = map.map_layers[flag]
				assert_true(not layer.get_used_cells().is_empty(), "%s/%s flag layer is empty" % [map_id, layer.name])
				for coordinates: Vector2i in layer.get_used_cells():
					assert_true(map.get_cell(coordinates).has_flag(flag), "%s/%s did not apply flag at %s" % [map_id, layer.name, coordinates])
		map.free()


func test_farm_coordinate_round_trip_and_cell_flags() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	var map := (load(MAP_PATHS[&"farm"]) as PackedScene).instantiate() as BaseMap
	scene_tree.root.add_child(map)
	var farm := map
	for cell: Vector2i in [Vector2i(2, 2), Vector2i(8, 10), Vector2i(15, 10), Vector2i(24, 16)]:
		var world := farm.cell_to_world(cell)
		assert_equal(farm.world_to_cell(world), cell)
	var map_size := farm.get_map_size()
	assert_equal(farm.cells.size(), map_size.x * map_size.y)
	assert_true(farm.get_cell(Vector2i(8, 10)).has_flag(CellState.CellFlag.DIGGABLE))
	assert_true(farm.get_cell(Vector2i(8, 10)).has_flag(CellState.CellFlag.DROPABLE))
	assert_true(farm.get_cell(Vector2i(15, 8)).has_flag(CellState.CellFlag.ROAD))
	assert_true(farm.get_cell(Vector2i(42, 27)).has_flag(CellState.CellFlag.BLOCKED))
	assert_true(farm.get_cell(Vector2i(8, 10)).has_flag(CellState.CellFlag.GENERATE))
	assert_true(not farm.get_cell(Vector2i(15, 8)).has_flag(CellState.CellFlag.GENERATE))
	assert_true(not farm.get_cell(Vector2i(42, 27)).has_flag(CellState.CellFlag.GENERATE))
	assert_true(not farm.check_cell(Vector2i(42, 27), CellState.CellCondition.WALKABLE))
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
	assert_true(map.setup(state) == OK)
	var map_cell := map.get_cell(Vector2i(5, 10))
	assert_true(map_cell.apply_tool(ToolMeta.ToolKind.HOE))
	assert_true(map_cell.apply_tool(ToolMeta.ToolKind.WATERING_CAN))
	assert_true(map_cell.has_flag(CellState.CellFlag.DUG))
	assert_true(map.check_cell(map_cell.coordinates, CellState.CellCondition.WATERED))
	map.free()


func test_rain_waters_every_dug_cell_and_rebuilds_projection() -> void:
	var previous_weather := CalendarManager.current_weather
	CalendarManager.current_weather = &"rain"
	var scene_tree := Engine.get_main_loop() as SceneTree
	var farm := (load(MAP_PATHS[&"farm"]) as PackedScene).instantiate() as BaseMap
	scene_tree.root.add_child(farm)
	var map_state := MapState.new()
	map_state.map_id = &"farm"
	assert_equal(farm.setup(map_state), OK)
	var first := farm.get_cell(Vector2i(8, 10))
	var second := farm.get_cell(Vector2i(9, 10))
	first.add_flag(CellState.CellFlag.DUG)
	second.add_flag(CellState.CellFlag.DUG)
	farm._on_day_advanced()
	assert_true(farm.check_cell(first.coordinates, CellState.CellCondition.WATERED))
	assert_true(farm.check_cell(second.coordinates, CellState.CellCondition.WATERED))
	var watered_layer := farm.get_node("TileMaps/WateredLayer") as TileMapLayer
	assert_true(watered_layer.get_cell_source_id(first.coordinates) >= 0)
	assert_true(watered_layer.get_cell_source_id(second.coordinates) >= 0)
	farm.free()
	CalendarManager.current_weather = previous_weather


func test_hoe_immediately_waters_newly_dug_cell_during_rain() -> void:
	var previous_weather := CalendarManager.current_weather
	CalendarManager.current_weather = &"rain"
	var scene_tree := Engine.get_main_loop() as SceneTree
	var farm := (load(MAP_PATHS[&"farm"]) as PackedScene).instantiate() as BaseMap
	scene_tree.root.add_child(farm)
	var map_state := MapState.new()
	map_state.map_id = &"farm"
	assert_equal(farm.setup(map_state), OK)
	var hoe_meta := ToolMeta.new()
	hoe_meta.id = &"hoe"
	hoe_meta.tool_kind = ToolMeta.ToolKind.HOE
	hoe_meta.is_cell_tool = true
	hoe_meta.base_energy_cost = 1
	var hoe := _test_tool(hoe_meta)
	var coordinates := Vector2i(8, 10)
	var outcome := hoe.use(farm, [coordinates], 10) as ApplyResult
	assert_true(outcome.succeeded())
	assert_true(farm.check_cell(coordinates, CellState.CellCondition.DUG))
	assert_true(farm.check_cell(coordinates, CellState.CellCondition.WATERED))
	assert_true((farm.get_node("TileMaps/WateredLayer") as TileMapLayer).get_cell_source_id(coordinates) >= 0)
	assert_equal((farm.get_node("TileMaps/DugLayer") as TileMapLayer).get_cell_source_id(coordinates), -1)
	hoe.free()
	farm.free()
	CalendarManager.current_weather = previous_weather


func test_tool_transaction_persists_and_rebuilds_farm_cell_projection() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	var farm := (load(MAP_PATHS[&"farm"]) as PackedScene).instantiate() as BaseMap
	scene_tree.root.add_child(farm)
	var map_state := MapState.new()
	map_state.map_id = &"farm"
	assert_equal(farm.setup(map_state), OK)
	var player_state := PlayerState.new()
	player_state.energy = 10
	var coordinates := Vector2i(8, 10)
	var hoe_meta := DataCatalog.get_item(&"hoe") as ToolMeta
	var hoe := _test_tool(hoe_meta)
	var hoe_result := hoe.use(farm, [coordinates], player_state.energy) as ApplyResult
	assert_true(hoe_result.succeeded())
	player_state.energy -= hoe_meta.base_energy_cost
	var watering_meta := DataCatalog.get_item(&"watering_can") as ToolMeta
	var watering_can := _test_tool(watering_meta)
	var water_result := watering_can.use(farm, [coordinates], player_state.energy) as ApplyResult
	assert_true(water_result.succeeded())
	assert_true(map_state.cells[coordinates].flags & CellState.CellFlag.DUG)
	assert_true(map_state.cells[coordinates].flags & CellState.CellFlag.WATERED)
	assert_true(farm.get_node_or_null("TileMaps/DugLayer") is TileMapLayer)
	assert_true(farm.get_node_or_null("TileMaps/WateredLayer") is TileMapLayer)

	var serialized := JSON.parse_string(JSON.stringify(map_state.to_dict())) as Dictionary
	var restored_state := MapState.from_dict(serialized)
	var restored_farm := (load(MAP_PATHS[&"farm"]) as PackedScene).instantiate() as BaseMap
	scene_tree.root.add_child(restored_farm)
	assert_equal(restored_farm.setup(restored_state), OK)
	assert_true(restored_farm.check_cell(coordinates, CellState.CellCondition.DUG))
	assert_true(restored_farm.check_cell(coordinates, CellState.CellCondition.WATERED))
	assert_true(restored_farm.get_node_or_null("TileMaps/DugLayer") is TileMapLayer)
	restored_farm.free()
	hoe.free()
	watering_can.free()
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
	persisted_item.unique_id = &"crop_5_9"
	persisted_item.meta_id = &"parsnip"
	persisted_cell.item_ids = [persisted_item.unique_id]
	first_state.cells[persisted_cell.cell] = persisted_cell
	first_state.items[persisted_item.unique_id] = persisted_item
	assert_equal(farm.setup(first_state), OK)
	assert_true(farm.get_cell(Vector2i(5, 9)).state == persisted_cell)
	assert_true(farm.check_cell(Vector2i(5, 9), CellState.CellCondition.DUG))
	assert_true(farm.items[&"crop_5_9"] is Plant)
	assert_true(farm.items[&"crop_5_9"].state == persisted_item)
	assert_true((farm.items[&"crop_5_9"] as Plant).state == persisted_item)
	assert_true((farm.items[&"crop_5_9"] as Plant).meta is PlantMeta)
	assert_true((farm.items[&"crop_5_9"] as Plant).meta == farm.items[&"crop_5_9"].meta)
	assert_equal(farm.move_item(persisted_item.unique_id, farm.cell_to_world(Vector2i(6, 9))), OK)
	assert_equal(farm.get_item_coord(persisted_item.unique_id), Vector2i(6, 9))
	assert_true(not farm.get_cell(Vector2i(5, 9)).has_item(persisted_item.unique_id))
	assert_true(farm.get_cell(Vector2i(6, 9)).has_item(persisted_item.unique_id))
	var replacement_state := MapState.new()
	replacement_state.map_id = &"farm"
	assert_equal(farm.setup(replacement_state), OK)
	assert_true(farm.get_cell(Vector2i(5, 9)).state != persisted_cell)
	assert_true(replacement_state.cells[Vector2i(5, 9)] == farm.get_cell(Vector2i(5, 9)).state)
	assert_true(not farm.check_cell(Vector2i(5, 9), CellState.CellCondition.DUG))
	assert_true(farm.items.is_empty())
	farm.free()


func test_each_map_owns_a_distinct_tilemap_hierarchy() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	var farm := (load(MAP_PATHS[&"farm"]) as PackedScene).instantiate() as BaseMap
	var field := (load(MAP_PATHS[&"field"]) as PackedScene).instantiate() as BaseMap
	var beach := (load(MAP_PATHS[&"beach"]) as PackedScene).instantiate() as BaseMap
	scene_tree.root.add_child(farm)
	scene_tree.root.add_child(field)
	scene_tree.root.add_child(beach)
	assert_true(farm.has_node("TileMaps/BaseLayer"))
	assert_true(farm.has_node("TileMaps/DugLayer"))
	assert_true(field.has_node("TileMaps/BaseLayer"))
	assert_true(field.has_node("TileMaps/HillLayer"))
	assert_true(beach.has_node("TileMaps/WaterLayer"))
	assert_true(beach.has_node("TileMaps/CoastLayer"))
	for map: BaseMap in [farm, field, beach]:
		var tilemaps := map.get_node("TileMaps") as Node2D
		assert_true(tilemaps != null)
		assert_equal(tilemaps.position, Vector2.ZERO)
		assert_equal(tilemaps.rotation, 0.0)
		assert_equal(tilemaps.scale, Vector2.ONE)
		assert_true(not map.map_layers.is_empty())
		for layer: Node in tilemaps.get_children():
			assert_true(layer is TileMapLayer)
		for child: Node in map.get_children():
			assert_true(not child is TileMapLayer)
	assert_true(farm.get_node("MapItems") is Node2D)
	assert_true(field.get_node("MapItems") is Node2D)
	assert_true(farm.item_hosts[ItemMeta.ItemType.MATERIAL] == farm.get_node("MapItems/Items"))
	assert_true(farm.item_hosts[ItemMeta.ItemType.PLANT] == farm.get_node("MapItems/Plants"))
	assert_true(farm.item_hosts[ItemMeta.ItemType.OBSTACLE] == farm.get_node("MapItems/Harvestables"))
	assert_true(field.item_hosts[ItemMeta.ItemType.PLANT] == field.get_node("MapItems/Plants"))
	assert_true(field.item_hosts[ItemMeta.ItemType.OBSTACLE] == field.get_node("MapItems/Harvestables"))
	var farm_state := MapState.new()
	farm_state.map_id = &"farm"
	assert_equal(farm.setup(farm_state), OK)
	var plant_state := PlantState.new()
	plant_state.unique_id = &"crop_runtime_test"
	plant_state.meta_id = &"parsnip"
	assert_equal(farm.add_item(ItemManager.create_from_state(plant_state), Vector2i(5, 9)), OK)
	var plant := farm.get_item(plant_state.unique_id)
	assert_true(plant.get_parent() == farm.get_node("MapItems/Plants"))
	assert_true(plant is Plant)
	assert_true((plant as Plant).state == plant_state)
	assert_equal(plant.item_id(), plant_state.unique_id)
	assert_equal(farm.items.size(), 1)
	farm.free()
	field.free()
	beach.free()


func test_field_path_and_beach_coast_are_irregular() -> void:
	var field := (load(MAP_PATHS[&"field"]) as PackedScene).instantiate() as BaseMap
	var road := field.get_node("TileMaps/RoadLayer") as TileMapLayer
	var road_rows: Dictionary[int, bool] = {}
	for cell: Vector2i in road.get_used_cells():
		road_rows[cell.y] = true
	assert_true(road_rows.size() >= 5)
	var beach := (load(MAP_PATHS[&"beach"]) as PackedScene).instantiate() as BaseMap
	var coast := beach.get_node("TileMaps/CoastLayer") as TileMapLayer
	var coast_columns: Dictionary[int, bool] = {}
	for cell: Vector2i in coast.get_used_cells():
		coast_columns[cell.x] = true
	assert_true(coast_columns.size() >= 8)
	field.free()
	beach.free()


func test_farm_house_has_authored_layers_door_furniture_and_indoor_behavior() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	var farm := (load(MAP_PATHS[&"farm"]) as PackedScene).instantiate() as BaseMap
	scene_tree.root.add_child(farm)
	var house := farm.get_node("House") as FarmHouse
	assert_true(house != null)
	for path: String in ["TileMaps/FloorLayer", "TileMaps/WallLayer", "TileMaps/RoofLayer"]:
		var layer := house.get_node(path) as TileMapLayer
		assert_true(not layer.get_used_cells().is_empty())
	var floor_layer := house.get_node("TileMaps/FloorLayer") as TileMapLayer
	var wall_layer := house.get_node("TileMaps/WallLayer") as TileMapLayer
	var roof_layer := house.get_node("TileMaps/RoofLayer") as TileMapLayer
	assert_true(roof_layer.tile_set != floor_layer.tile_set)
	assert_equal(floor_layer.z_index, 0)
	assert_equal(wall_layer.z_index, 2)
	assert_true(roof_layer.z_index > wall_layer.z_index)
	assert_true(house.z_index + roof_layer.z_index > 3)
	for house_cell: Vector2i in roof_layer.get_used_cells():
		var world_position := roof_layer.to_global(roof_layer.map_to_local(house_cell))
		var farm_cell := farm.world_to_cell(world_position)
		assert_true(
			not farm.get_cell(farm_cell).has_flag(CellState.CellFlag.GENERATE),
			"House cell %s must not overlap farm GenerateLayer" % farm_cell
		)
	for node_name: String in ["Door", "Bed", "Television", "Fireplace", "WallCollision", "InteriorArea"]:
		assert_true(house.has_node(node_name))
	assert_equal((house.get_node("Door") as Polygon2D).z_index, floor_layer.z_index)
	for furniture_name: String in ["Bed", "Television", "Fireplace"]:
		assert_equal((house.get_node(furniture_name) as Polygon2D).z_index, 0)
	var player := (load("res://scenes/actors/player/player.tscn") as PackedScene).instantiate() as FarmPlayer
	player.camera_zoom_duration = 0.0
	scene_tree.root.add_child(player)
	house._on_body_entered(player)
	assert_true(house.roof_layer.visible)
	assert_true(house.roof_layer.modulate.a < 1.0)
	assert_equal(player.camera.zoom, player.indoor_camera_zoom)
	house._on_body_exited(player)
	assert_true(house.roof_layer.visible)
	assert_equal(house.roof_layer.modulate.a, 1.0)
	assert_equal(player.camera.zoom, Vector2.ONE)
	player.free()
	farm.free()


func test_base_map_item_helpers_handle_missing_values() -> void:
	var base_map := BaseMap.new()
	assert_equal(base_map.add_item(null, Vector2i.ZERO), ERR_INVALID_PARAMETER)
	var state := ItemState.new()
	state.unique_id = &"item_test"
	state.meta_id = &"wood"
	var item := Item.new(state)
	assert_equal(base_map.add_item(item, Vector2i.ZERO), ERR_DOES_NOT_EXIST)
	assert_equal(base_map.items.size(), 0)
	item.free()
	base_map.free()


func test_base_map_rejects_meta_state_mismatch() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	var field := (load(MAP_PATHS[&"field"]) as PackedScene).instantiate() as BaseMap
	scene_tree.root.add_child(field)
	var map_state := MapState.new()
	map_state.map_id = &"field"
	assert_equal(field.setup(map_state), OK)
	var invalid_crop := ItemState.new()
	invalid_crop.unique_id = &"invalid_crop"
	invalid_crop.meta_id = &"parsnip"
	assert_equal(field.add_item(ItemManager.create_from_state(invalid_crop), Vector2i(5, 9)), ERR_INVALID_PARAMETER)
	var harvestable := HarvestableState.new()
	harvestable.unique_id = &"tree_runtime"
	harvestable.meta_id = &"tree"
	assert_equal(field.add_item(ItemManager.create_from_state(harvestable), Vector2i(5, 9)), OK)
	var runtime_item := field.get_item(harvestable.unique_id)
	assert_true(runtime_item is Harvestable)
	assert_true((runtime_item as Harvestable).state == harvestable)
	assert_true((runtime_item as Harvestable).meta is HarvestableMeta)
	assert_true((runtime_item as Harvestable).meta == runtime_item.meta)
	field.free()


func _test_tool(item_meta: ToolMeta) -> Tool:
	var item_state := ItemState.new()
	item_state.unique_id = StringName("test_%s" % item_meta.id)
	item_state.meta_id = item_meta.id
	var tool := Tool.new(item_state)
	tool.meta = item_meta
	return tool
