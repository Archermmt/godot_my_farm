extends ProjectTestCase

var _nodes: Array[Node] = []


func after_each() -> void:
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


func test_harvest_tools_validate_damage_and_single_energy_cost() -> void:
	var map := _make_map()
	_add_harvestable(map, &"rock_a", &"rock", Vector2i(1, 1), 3)
	_add_harvestable(map, &"grass_a", &"grass", Vector2i(2, 1), 1)
	var axe_meta := DataCatalog.get_item(&"axe") as ToolMeta
	var axe := _tool(axe_meta)
	assert_equal(axe.harvest_rejection_reason(map, Vector2i(1, 1)), &"wrong_tool")
	assert_equal(axe.use(map, [Vector2i(1, 1)], 10).error, ERR_UNAVAILABLE)
	assert_equal((map.get_item(&"rock_a") as Harvestable).get_state().health, 3)

	var pickaxe_meta := DataCatalog.get_item(&"pickaxe") as ToolMeta
	var result := _tool(pickaxe_meta).use(map, [Vector2i(1, 1), Vector2i(1, 1)], 10)
	assert_equal(result.error, OK)
	assert_equal(result.energy_spent, pickaxe_meta.base_energy_cost)
	assert_equal(result.effect_cells, [Vector2i(1, 1)])
	assert_equal((map.get_item(&"rock_a") as Harvestable).get_state().health, 2)
	assert_equal(result.skipped_reasons[Vector2i(1, 1)], &"duplicate")


func test_pickaxe_and_axe_charge_level_scales_damage() -> void:
	var map := _make_map()
	_add_harvestable(map, &"rock_charged", &"rock", Vector2i(1, 1), 3)
	_add_harvestable(map, &"tree_charged", &"tree", Vector2i(2, 1), 5)
	var pickaxe := _tool(DataCatalog.get_item(&"pickaxe") as ToolMeta)
	var axe := _tool(DataCatalog.get_item(&"axe") as ToolMeta)
	var pickaxe_result := pickaxe.use(map, [Vector2i(1, 1)], 10, Vector2i.ZERO, 1)
	var axe_result := axe.use(map, [Vector2i(2, 1)], 10, Vector2i.ZERO, 2)
	assert_equal(pickaxe_result.error, OK)
	assert_equal(axe_result.error, OK)
	assert_equal((map.get_item(&"rock_charged") as Harvestable).get_state().health, 1)
	assert_equal((map.get_item(&"tree_charged") as Harvestable).get_state().health, 2)


func test_death_drops_once_and_tree_becomes_stump() -> void:
	var map := _make_map()
	map.drop_rng.seed = 77
	var tree := _add_harvestable(map, &"tree_a", &"tree", Vector2i(2, 2), 1)
	var axe := _tool(DataCatalog.get_item(&"axe") as ToolMeta)
	var result := axe.use(map, [Vector2i(2, 2)], 10, Vector2i(1, 2), 0, 0.5) as ItemToolOutcome
	assert_equal(result.error, OK)
	assert_true(map.get_item(&"tree_a") == null)
	assert_true(is_instance_valid(tree))
	assert_true(not tree.is_queued_for_deletion())
	assert_equal(result.destroyed_item_ids, [&"tree_a"])
	assert_true(result.pickup_ids.size() >= 2 and result.pickup_ids.size() <= 4)
	assert_equal(result.tree_fall_directions[&"tree_a"], 1)
	var stump := map.harvestable_at(Vector2i(2, 2))
	assert_true(stump != null)
	assert_equal(stump.meta.id, &"stump")
	assert_equal(map.resolve_depleted_item(&"tree_a"), [])
	assert_equal(_pickup_count(map), result.pickup_ids.size())
	stump.get_state().health = 1
	var stump_result := axe.use(map, [Vector2i(2, 2)], 10)
	assert_equal(stump_result.error, OK)
	assert_true(map.harvestable_at(Vector2i(2, 2)) == null)
	assert_equal(_pickup_count(map), result.pickup_ids.size())
	for pickup_id: StringName in result.pickup_ids:
		assert_equal((map.get_item(pickup_id) as Item).pickup_delay, 0.5)
	tree._hit_flash_tween.custom_step(1.0)
	assert_true(tree.is_queued_for_deletion())


func test_harvestable_health_changes_stage_texture() -> void:
	var map := _make_map()
	var tree := _add_harvestable(map, &"tree_visual", &"tree", Vector2i(2, 2), 5)
	var visual := tree.get_node("StageVisual") as Sprite2D
	assert_equal(tree.health_stage().min_health, 4)
	var healthy_texture := visual.texture
	assert_equal(tree.apply_tool(ToolMeta.ToolKind.AXE, 2), ItemMeta.ItemFlag.AVAILABLE)
	assert_equal(tree.get_state().health, 3)
	assert_equal(tree.health_stage().min_health, 2)
	assert_true(visual.texture != healthy_texture)
	var damaged_texture := visual.texture
	assert_equal(tree.apply_tool(ToolMeta.ToolKind.AXE, 2), ItemMeta.ItemFlag.AVAILABLE)
	assert_equal(tree.get_state().health, 1)
	assert_equal(tree.health_stage().min_health, 1)
	assert_true(visual.texture != damaged_texture)


func test_harvestable_hit_flash_uses_instance_local_shader_material() -> void:
	var map := _make_map()
	var first := _add_harvestable(map, &"tree_flash_a", &"tree", Vector2i(2, 2), 5)
	var second := _add_harvestable(map, &"tree_flash_b", &"tree", Vector2i(3, 2), 5)
	var first_material := (first.get_node("StageVisual") as Sprite2D).material as ShaderMaterial
	var second_material := (second.get_node("StageVisual") as Sprite2D).material as ShaderMaterial
	assert_true(first_material != null)
	assert_true(second_material != null)
	assert_true(first_material != second_material)
	assert_equal(float(first_material.get_shader_parameter(&"flash_amount")), 0.0)
	assert_equal(first.apply_tool(ToolMeta.ToolKind.PICKAXE, 1), ItemMeta.ItemFlag.WRONG_TOOL)
	assert_equal(float(first_material.get_shader_parameter(&"flash_amount")), 0.0)
	assert_equal(first.apply_tool(ToolMeta.ToolKind.AXE, 1), ItemMeta.ItemFlag.AVAILABLE)
	assert_equal(float(first_material.get_shader_parameter(&"flash_amount")), 1.0)
	assert_equal(float(second_material.get_shader_parameter(&"flash_amount")), 0.0)
	first._hit_flash_tween.custom_step(1.0)
	assert_equal(float(first_material.get_shader_parameter(&"flash_amount")), 0.0)
	var plant := _add_plant(map, &"plant_flash", Vector2i(4, 2), 6)
	var plant_material := (plant.get_node("StageVisual") as Sprite2D).material as ShaderMaterial
	assert_true(plant_material != null)
	assert_equal(plant.apply_tool(ToolMeta.ToolKind.BASKET, 1), ItemMeta.ItemFlag.AVAILABLE)
	assert_equal(float(plant_material.get_shader_parameter(&"flash_amount")), 1.0)


func test_depleted_grass_keeps_visual_until_flash_finishes() -> void:
	var map := _make_map()
	var grass := _add_harvestable(map, &"grass_flash", &"grass", Vector2i(2, 2), 1)
	var visual := grass.get_node("StageVisual") as Sprite2D
	assert_true(visual.texture != null)
	var result := _tool(DataCatalog.get_item(&"sickle") as ToolMeta).use(map, [Vector2i(2, 2)], 10) as ItemToolOutcome
	assert_equal(result.error, OK)
	assert_true(map.get_item(&"grass_flash") == null)
	assert_true(visual.texture != null)
	assert_equal(float((visual.material as ShaderMaterial).get_shader_parameter(&"flash_amount")), 1.0)
	assert_true(not grass.is_queued_for_deletion())
	grass._hit_flash_tween.custom_step(1.0)
	assert_true(grass.is_queued_for_deletion())


func test_mature_plant_harvest_preserves_dug_and_immature_is_rejected() -> void:
	var map := _make_map(CellState.CellFlag.BASE | CellState.CellFlag.DROPABLE, CellState.CellFlag.DUG)
	var immature := _add_plant(map, &"parsnip_a", Vector2i(1, 1), 0)
	assert_true(map.check_cell(Vector2i(1, 1), BaseMap.CellCondition.HAS_OCCUPANT))
	var basket_meta := DataCatalog.get_item(&"basket") as ToolMeta
	var basket := _tool(basket_meta)
	assert_equal(basket.harvest_rejection_reason(map, Vector2i(1, 1)), &"not_mature")
	immature.get_state().growth_days = 6
	immature.get_state().health = 1
	var result := basket.use(map, [Vector2i(1, 1)], 10) as ItemToolOutcome
	assert_equal(result.error, OK)
	assert_true(result.pickup_ids.size() >= 1 and result.pickup_ids.size() <= 2)
	assert_true(map.get_cell(Vector2i(1, 1)).is_dug())
	assert_true(map.harvestable_at(Vector2i(1, 1)) == null)
	assert_equal((map.get_item(result.pickup_ids[0]) as Item).state.meta_id, &"parsnip_harvest")
	assert_true(map.check_cell(Vector2i(1, 1), BaseMap.CellCondition.PLANTABLE))


func test_pickup_is_non_blocking_and_persists_while_inventory_is_full() -> void:
	var map := _make_map(CellState.CellFlag.BASE | CellState.CellFlag.DROPABLE, CellState.CellFlag.DUG)
	var pickup := _add_pickup(map, &"pickup_stone", &"stone", Vector2i(1, 1))
	assert_true(not map.check_cell(Vector2i(1, 1), BaseMap.CellCondition.HAS_OCCUPANT))
	assert_true(map.check_cell(Vector2i(1, 1), BaseMap.CellCondition.PLANTABLE))
	assert_true(map.check_cell(Vector2i(1, 1), BaseMap.CellCondition.DROPABLE))
	var player := _make_pickup_player()
	player.state = PlayerState.new()
	player.backpack.setup(BackpackState.new(1, 0, 1))
	player.backpack.backpack_state.set_slot(&"itembar", 0, BackpackSlot.new(&"itembar_0", &"wood", 99))
	player.backpack.backpack_state.set_slot(&"main_space", 0, BackpackSlot.new(&"main_space_0", &"wood", 99))
	player.global_position = pickup.global_position
	assert_true(not player._process_pickup(pickup, map, 0.0))
	assert_true(map.get_item(&"pickup_stone") == pickup)

	player.backpack.backpack_state.get_slot(&"itembar", 0).clear()
	assert_true(player._process_pickup(pickup, map, 0.0))
	assert_equal(player.backpack.backpack_state.count_item(&"itembar", &"stone"), 1)
	assert_equal(player.backpack.backpack_state.count_item(&"main_space", &"stone"), 0)
	assert_true(map.get_item(&"pickup_stone") == null)


func test_pickup_overflows_from_itembar_to_inventory() -> void:
	var map := _make_map()
	var pickup := _add_pickup(map, &"pickup_stone_overflow", &"stone", Vector2i(1, 1))
	var player := _make_pickup_player()
	player.state = PlayerState.new()
	player.backpack.setup(BackpackState.new(1, 0, 1))
	player.backpack.backpack_state.set_slot(&"itembar", 0, BackpackSlot.new(&"itembar_0", &"wood", 99))
	player.global_position = pickup.global_position
	assert_true(player._process_pickup(pickup, map, 0.0))
	assert_equal(player.backpack.backpack_state.count_item(&"itembar", &"stone"), 0)
	assert_equal(player.backpack.backpack_state.count_item(&"main_space", &"stone"), 1)


func test_pickup_state_round_trip_and_cell_sync() -> void:
	var map := _make_map()
	var pickup := _add_pickup(map, &"pickup_wood", &"wood", Vector2i(0, 0))
	var restored := ItemCodec.from_dict(ItemCodec.to_dict(pickup.state))
	assert_true(restored != null)
	assert_equal(restored.instance_id, &"pickup_wood")
	pickup.global_position = map.cell_to_world_center(Vector2i(2, 1))
	assert_equal(map.sync_item_cell_from_position(pickup.item_id()), OK)
	assert_equal(pickup.state.cell, Vector2i(2, 1))
	assert_true(map.get_cell(Vector2i(2, 1)).has_item(&"pickup_wood"))
	assert_true(not map.get_cell(Vector2i(0, 0)).has_item(&"pickup_wood"))


func test_pickup_partially_fills_stack_and_retains_remainder() -> void:
	var map := _make_map()
	var pickup := _add_pickup(map, &"pickup_wood_partial", &"wood", Vector2i(1, 1))
	var player := _make_pickup_player()
	player.state = PlayerState.new()
	player.backpack.setup(BackpackState.new(1, 0, 1))
	player.backpack.backpack_state.set_slot(&"itembar", 0, BackpackSlot.new(&"itembar_0", &"wood", 97))
	player.backpack.backpack_state.set_slot(&"main_space", 0, BackpackSlot.new(&"main_space_0", &"stone", 99))
	player.global_position = pickup.global_position
	assert_true(player._process_pickup(pickup, map, 0.0))
	assert_equal(player.backpack.backpack_state.count_item(&"itembar", &"wood"), 98)
	assert_equal(player.backpack.backpack_state.count_item(&"main_space", &"wood"), 0)
	assert_true(map.get_item(&"pickup_wood_partial") == null)


func test_drop_roll_is_seeded_and_within_catalog_bounds() -> void:
	var map := _make_map()
	map.drop_rng.seed = 1234
	var rock_meta := DataCatalog.get_harvestable(&"rock")
	var first := map.roll_drops(rock_meta.drops)
	map.drop_rng.seed = 1234
	var second := map.roll_drops(rock_meta.drops)
	assert_equal(first, second)
	assert_equal(first.size(), 1)
	assert_true(int(first[0]["amount"]) >= 1)
	assert_true(int(first[0]["amount"]) <= 3)


func test_map_pickup_query_only_returns_loose_items_inside_radius() -> void:
	var map := _make_map()
	var near := _add_pickup(map, &"pickup_near", &"stone", Vector2i(1, 1))
	var far := _add_pickup(map, &"pickup_far", &"wood", Vector2i(4, 4))
	_add_harvestable(map, &"grass_near", &"grass", Vector2i(1, 2), 1)
	var center := near.global_position
	var found := map.pickup_items_in_radius(center, 40.0)
	assert_equal(found, [near])
	assert_true(far not in found)


func test_pickup_delay_is_bound_by_spawn_source() -> void:
	var player := _make_pickup_player()
	assert_equal(player.pickup_delay_for(&"drop"), 1.0)
	assert_equal(player.pickup_delay_for(&"harvestable"), 0.5)
	assert_equal(player.pickup_delay_for(&"generate"), 0.0)
	assert_true(player.pickup_speed_curve != null)
	assert_true(player.pickup_speed_curve.sample_baked(0.9) > player.pickup_speed_curve.sample_baked(0.5))
	assert_true(player.pickup_speed_curve.sample_baked(0.5) > player.pickup_speed_curve.sample_baked(0.1))
	var map := _make_map()
	var dropped_id := map.spawn_pickup(&"stone", Vector2i(1, 1), player.pickup_delay_for(&"drop"))
	var harvested_id := map.spawn_pickup(&"wood", Vector2i(2, 1), player.pickup_delay_for(&"harvestable"))
	var generated := _add_pickup(map, &"generated_ready", &"stone", Vector2i(3, 1))
	assert_equal((map.get_item(dropped_id) as Item).pickup_delay, 1.0)
	assert_equal((map.get_item(harvested_id) as Item).pickup_delay, 0.5)
	assert_equal(generated.pickup_delay, 0.0)


func test_generator_uses_generate_pickup_delay_without_waiting() -> void:
	var map := _make_map()
	var state := ItemState.new()
	state.instance_id = &"generated_stone"
	state.meta_id = &"stone"
	state.flags = [&"generated"]
	assert_equal(map.add_item_state(state, Vector2i(3, 1), 0.0), OK)
	var generated := map.get_item(state.instance_id)
	assert_equal(generated.pickup_delay, 0.0)
	var player := _make_pickup_player()
	player.state = PlayerState.new()
	player.global_position = generated.global_position + Vector2(40.0, 0.0)
	var before := generated.global_position
	assert_true(not player._process_pickup(generated, map, 0.05))
	assert_true(
		generated.global_position.distance_to(player.global_position) < before.distance_to(player.global_position)
	)


func test_leaving_pickup_area_clears_delay_before_reentry() -> void:
	var map := _make_map()
	var pickup_id := map.spawn_pickup(&"stone", Vector2i(1, 1))
	var pickup := map.get_item(pickup_id)
	var player := _make_pickup_player()
	player.state = PlayerState.new()
	player.global_position = pickup.global_position + Vector2(40.0, 0.0)
	assert_true(not player._process_pickup(pickup, map, 0.0))
	assert_equal(pickup.pickup_delay, 1.0)
	player.global_position = pickup.global_position + Vector2(100.0, 0.0)
	map.pickup_items_in_radius(player.global_position, player.pickup_radius)
	assert_equal(pickup.pickup_delay, 0.0)
	player.global_position = pickup.global_position + Vector2(40.0, 0.0)
	var before := pickup.global_position
	assert_true(not player._process_pickup(pickup, map, 0.05))
	assert_true(pickup.global_position.distance_to(player.global_position) < before.distance_to(player.global_position))


func test_pickup_delay_expires_while_player_remains_in_pickup_area() -> void:
	var map := _make_map()
	var pickup_id := map.spawn_pickup(&"stone", Vector2i(1, 1))
	var pickup := map.get_item(pickup_id)
	var player := _make_pickup_player()
	player.state = PlayerState.new()
	player.global_position = pickup.global_position + Vector2(40.0, 0.0)
	assert_true(not player._process_pickup(pickup, map, 0.5))
	assert_equal(pickup.pickup_delay, 0.5)
	assert_true(not player._process_pickup(pickup, map, 0.5))
	assert_equal(pickup.pickup_delay, 0.0)
	assert_true(pickup.global_position.distance_to(player.global_position) < 40.0)


func test_player_moves_pickup_before_collecting_and_map_only_deletes_after_success() -> void:
	var map := _make_map()
	var pickup := _add_pickup(map, &"pickup_moving", &"stone", Vector2i(2, 1))
	var player := _make_pickup_player()
	player.state = PlayerState.new()
	player.global_position = pickup.global_position + Vector2(40.0, 0.0)
	var before := pickup.global_position
	assert_true(not player._process_pickup(pickup, map, 0.05))
	assert_true(pickup.global_position.distance_to(player.global_position) < before.distance_to(player.global_position))
	assert_true(map.get_item(&"pickup_moving") == pickup)


func test_spawned_pickup_delays_attraction_but_allows_contact_pickup() -> void:
	var map := _make_map()
	var pickup_id := map.spawn_pickup(&"stone", Vector2i(1, 1))
	var pickup := map.get_item(pickup_id)
	var player := _make_pickup_player()
	player.state = PlayerState.new()
	player.global_position = pickup.global_position + Vector2(40.0, 0.0)
	assert_true(not player._process_pickup(pickup, map, 0.0))
	assert_true(map.get_item(pickup_id) == pickup)
	player.global_position = pickup.global_position
	assert_true(player._process_pickup(pickup, map, 0.0))
	assert_true(map.get_item(pickup_id) == null)


func test_new_game_farm_generation_populates_runtime_hosts() -> void:
	var game_manager := GameManagerService.new()
	_nodes.append(game_manager)
	assert_equal(game_manager.new_game(31415), OK)
	var map := (load("res://scenes/maps/farm/farm.tscn") as PackedScene).instantiate() as BaseMap
	_nodes.append(map)
	(Engine.get_main_loop() as SceneTree).root.add_child(map)
	assert_equal(map.configure_state(game_manager.maps[&"farm"], game_manager.world_seed, true), OK)
	assert_true(map.items.size() > 0)
	var harvestable_count := 0
	var loose_item_count := 0
	for generated_item: Item in map.items.values():
		if generated_item is Harvestable:
			harvestable_count += 1
			var harvestable_meta := generated_item.meta as HarvestableMeta
			if harvestable_meta != null and harvestable_meta.blocks_movement:
				assert_true(generated_item.has_node("Obstacle"))
		elif generated_item.meta != null and generated_item.meta.can_pickup:
			loose_item_count += 1
	assert_true(harvestable_count > 0)
	assert_true(loose_item_count > 0)
	assert_equal(map.harvestables_host.get_child_count(), harvestable_count)
	assert_equal(map.items_host.get_child_count(), loose_item_count)
	assert_equal(map.plants_host.get_child_count(), 0)
	var pickup_id := map.spawn_pickup(&"stone", Vector2i(11, 8))
	assert_true(pickup_id != &"")
	assert_true(not map.get_item(pickup_id).has_node("PlayerDetector"))


func _make_map(meta_flags: int = CellState.CellFlag.BASE, state_flags: int = 0) -> BaseMap:
	var map := (load("res://scenes/maps/field/field.tscn") as PackedScene).instantiate() as BaseMap
	_nodes.append(map)
	(Engine.get_main_loop() as SceneTree).root.add_child(map)
	var state := MapState.new()
	state.map_id = map.map_id
	assert_equal(map.configure_state(state), OK)
	for coordinates: Vector2i in map.cells:
		map.get_cell(coordinates).static_flags = meta_flags
		map.get_cell(coordinates).set_state_flags(state_flags)
	return map


func _add_harvestable(map: BaseMap, id: StringName, meta_id: StringName, cell: Vector2i, health: int) -> Harvestable:
	var state := HarvestableState.new()
	state.instance_id = id
	state.meta_id = meta_id
	state.cell = cell
	state.health = health
	assert_equal(map.add_item_state(state, cell), OK)
	return map.get_item(id) as Harvestable


func _add_plant(map: BaseMap, id: StringName, cell: Vector2i, growth_days: int) -> Plant:
	var state := PlantState.new()
	state.instance_id = id
	state.meta_id = &"parsnip"
	state.cell = cell
	state.planted_on_day = 1
	state.growth_days = growth_days
	assert_equal(map.add_item_state(state, cell), OK)
	return map.get_item(id) as Plant


func _add_pickup(map: BaseMap, id: StringName, meta_id: StringName, cell: Vector2i) -> Item:
	var state := ItemState.new()
	state.instance_id = id
	state.meta_id = meta_id
	state.cell = cell
	assert_equal(map.add_item_state(state, cell), OK)
	return map.get_item(id) as Item


func _make_pickup_player() -> FarmPlayer:
	var player := (load("res://scenes/actors/player/player.tscn") as PackedScene).instantiate() as FarmPlayer
	_nodes.append(player)
	return player


func _tool(meta: ToolMeta) -> Tool:
	var tool := Tool.new(meta)
	_nodes.append(tool)
	return tool


func _pickup_count(map: BaseMap) -> int:
	var count := 0
	for item: Item in map.items.values():
		if item != null and item.meta != null and item.meta.can_pickup:
			count += 1
	return count
