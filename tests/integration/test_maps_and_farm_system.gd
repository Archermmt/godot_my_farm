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
		assert_true(map.spawn_position(&"default") != Vector2.ZERO)
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
				assert_true(map.get_cell(coordinates).has_flag(flag), "%s/%s did not apply flag at %s" % [map_id, layer.name, coordinates])
		map.free()

func test_farm_coordinate_round_trip_and_cell_flags() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	var map := (load(MAP_PATHS[&"farm"]) as PackedScene).instantiate() as BaseMap
	scene_tree.root.add_child(map)
	var farm := map
	for cell: Vector2i in [Vector2i(2, 2), Vector2i(8, 10), Vector2i(15, 10), Vector2i(24, 16)]:
		var world := farm.cell_to_world_center(cell)
		assert_equal(farm.world_to_cell(world), cell)
	assert_equal(farm.cells.size(), farm.map_size.x * farm.map_size.y)
	assert_true(farm.get_cell(Vector2i(8, 10)).has_flag(CellState.CellFlag.DIGGABLE))
	assert_true(farm.get_cell(Vector2i(8, 10)).has_flag(CellState.CellFlag.DROPABLE))
	assert_true(farm.get_cell(Vector2i(15, 10)).has_flag(CellState.CellFlag.ROAD))
	assert_true(farm.get_cell(Vector2i(24, 16)).has_flag(CellState.CellFlag.BLOCKED))
	assert_true(not farm.is_walkable(Vector2i(24, 16)))
	assert_equal(farm.get_cells_in_rect(Rect2i(3, 8, 2, 2)).size(), 4)
	map.free()

func test_dynamic_cell_state_is_not_tilemap_authority() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	var map := (load(MAP_PATHS[&"farm"]) as PackedScene).instantiate() as BaseMap
	scene_tree.root.add_child(map)
	var state: MapState = GameState.maps[&"farm"]
	assert_true(map.configure_state(state) == OK)
	var map_cell := map.get_cell(Vector2i(5, 9))
	assert_equal(map_cell.dig(), OK)
	assert_equal(map_cell.water(0), OK)
	assert_true(map_cell.cell_state().dug)
	assert_true(map_cell.is_watered(0))
	map.free()

func test_base_map_restores_and_operates_on_state_dtos() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	var farm := (load(MAP_PATHS[&"farm"]) as PackedScene).instantiate() as BaseMap
	scene_tree.root.add_child(farm)
	var first_state := MapState.new()
	first_state.map_id = &"farm"
	var persisted_cell := CellState.new()
	persisted_cell.cell = Vector2i(5, 9)
	persisted_cell.dug = true
	var persisted_entity := EntityState.new()
	persisted_entity.instance_id = &"crop_5_9"
	persisted_entity.definition_id = &"crop_parsnip"
	persisted_entity.type = EntityState.EntityType.CROP
	persisted_entity.seed_item_id = &"seed_parsnip"
	persisted_entity.cell = persisted_cell.cell
	persisted_cell.entity_ids = [persisted_entity.instance_id]
	first_state.cells[persisted_cell.cell] = persisted_cell
	first_state.entities[persisted_entity.instance_id] = persisted_entity
	assert_equal(farm.configure_state(first_state), OK)
	assert_true(farm.get_cell(Vector2i(5, 9)).cell_state() == persisted_cell)
	assert_true(farm.get_cell(Vector2i(5, 9)).is_dug())
	assert_true(farm.entities[&"crop_5_9"] is CropEntity)
	assert_true(farm.entities[&"crop_5_9"].state == persisted_entity)
	assert_equal(farm.move_entity(persisted_entity.instance_id, Vector2i(6, 9)), OK)
	assert_equal(persisted_entity.cell, Vector2i(6, 9))
	assert_true(not farm.get_cell(Vector2i(5, 9)).has_entity(persisted_entity.instance_id))
	assert_true(farm.get_cell(Vector2i(6, 9)).has_entity(persisted_entity.instance_id))
	var replacement_state := MapState.new()
	replacement_state.map_id = &"farm"
	assert_equal(farm.configure_state(replacement_state), OK)
	assert_true(farm.get_cell(Vector2i(5, 9)).cell_state() != persisted_cell)
	assert_true(replacement_state.cells[Vector2i(5, 9)] == farm.get_cell(Vector2i(5, 9)).cell_state())
	assert_true(farm.entities.is_empty())
	farm.free()

func test_each_map_owns_a_distinct_tilemap_hierarchy() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	var farm := (load(MAP_PATHS[&"farm"]) as PackedScene).instantiate() as BaseMap
	var field := (load(MAP_PATHS[&"field"]) as PackedScene).instantiate() as BaseMap
	var cabin := (load(MAP_PATHS[&"cabin"]) as PackedScene).instantiate() as BaseMap
	scene_tree.root.add_child(farm)
	scene_tree.root.add_child(field)
	scene_tree.root.add_child(cabin)
	assert_true(farm.has_node("BaseLayer"))
	assert_true(not farm.has_node("DugLayer"))
	assert_true(field.has_node("GroundLayer"))
	assert_true(field.has_node("ResourceLayer"))
	assert_true(cabin.has_node("FloorLayer"))
	assert_true(cabin.has_node("WallLayer"))
	for map: BaseMap in [farm, field, cabin]:
		for child: Node in map.get_children():
			if child is TileMapLayer:
				continue
			assert_true(child.name != "FarmGrid" and child.name != "FieldGrid" and child.name != "CabinGrid")
	assert_true(farm.get_node("MapEntities") is Node2D)
	assert_true(field.get_node("MapEntities") is Node2D)
	assert_true(farm.entity_host(EntityState.EntityType.GENERIC) == farm.get_node("MapEntities/Entities"))
	assert_true(farm.entity_host(EntityState.EntityType.CROP) == farm.get_node("MapEntities/Crops"))
	var farm_state := MapState.new()
	farm_state.map_id = &"farm"
	assert_equal(farm.configure_state(farm_state), OK)
	var crop_state := EntityState.new()
	crop_state.instance_id = &"crop_runtime_test"
	crop_state.definition_id = &"crop_parsnip"
	crop_state.type = EntityState.EntityType.CROP
	crop_state.seed_item_id = &"seed_parsnip"
	crop_state.cell = Vector2i(5, 9)
	assert_equal(farm.add_entity_state(crop_state), OK)
	var crop := farm.get_entity(crop_state.instance_id)
	assert_true(crop.get_parent() == farm.get_node("MapEntities/Crops"))
	assert_true(crop is CropEntity)
	assert_equal(crop.entity_id(), crop_state.instance_id)
	assert_equal(farm.entity_count(EntityState.EntityType.CROP), 1)
	assert_equal(farm.entity_count(), 1)
	farm.free()
	field.free()
	cabin.free()

func test_base_map_entity_helpers_handle_missing_values() -> void:
	var base_map := BaseMap.new()
	assert_equal(base_map.add_entity(null), ERR_INVALID_PARAMETER)
	var state := EntityState.new()
	state.instance_id = &"entity_test"
	state.definition_id = &"test"
	var entity := Entity.new()
	assert_equal(entity.bind_state(state), OK)
	assert_equal(base_map.add_entity(entity), ERR_UNCONFIGURED)
	assert_equal(base_map.entity_count(), 0)
	entity.free()
	base_map.free()
