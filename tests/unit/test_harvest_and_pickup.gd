extends ProjectTestCase

var _nodes: Array[Node] = []


func after_each() -> void:
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


func test_harvest_tools_validate_damage_and_single_stamina_cost() -> void:
	var map := _make_map()
	_add_harvestable(map, &"rock_a", &"rock", Vector2i(1, 1), 3)
	_add_harvestable(map, &"grass_a", &"grass", Vector2i(2, 1), 1)
	var axe_meta := DataCatalog.get_item(&"tool_axe") as ToolMeta
	var axe := _tool(axe_meta)
	assert_equal(axe.harvest_rejection_reason(map, Vector2i(1, 1)), &"wrong_tool")
	assert_equal(axe.use(map, [Vector2i(1, 1)], 10).error, ERR_UNAVAILABLE)
	assert_equal((map.get_item(&"rock_a") as Harvestable).harvestable_state().health, 3)

	var pickaxe_meta := DataCatalog.get_item(&"tool_pickaxe") as ToolMeta
	var result := _tool(pickaxe_meta).use(map, [Vector2i(1, 1), Vector2i(1, 1)], 10)
	assert_equal(result.error, OK)
	assert_equal(result.stamina_spent, pickaxe_meta.base_stamina_cost)
	assert_equal(result.effect_cells, [Vector2i(1, 1)])
	assert_equal((map.get_item(&"rock_a") as Harvestable).harvestable_state().health, 2)
	assert_equal(result.skipped_reasons[Vector2i(1, 1)], &"duplicate")


func test_death_drops_once_and_tree_becomes_stump() -> void:
	var map := _make_map()
	map.drop_rng.seed = 77
	var tree := _add_harvestable(map, &"tree_a", &"tree", Vector2i(2, 2), 1)
	var axe := _tool(DataCatalog.get_item(&"tool_axe") as ToolMeta)
	var result := axe.use(map, [Vector2i(2, 2)], 10, Vector2i(1, 2)) as ItemToolOutcome
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
	stump.harvestable_state().health = 1
	var stump_result := axe.use(map, [Vector2i(2, 2)], 10)
	assert_equal(stump_result.error, OK)
	assert_true(map.harvestable_at(Vector2i(2, 2)) == null)
	assert_equal(_pickup_count(map), result.pickup_ids.size())
	tree._hit_flash_tween.custom_step(1.0)
	assert_true(tree.is_queued_for_deletion())


func test_harvestable_health_changes_stage_texture() -> void:
	var map := _make_map()
	var tree := _add_harvestable(map, &"tree_visual", &"tree", Vector2i(2, 2), 5)
	var visual := tree.get_node("StageVisual") as Sprite2D
	assert_equal(tree.health_stage().min_health, 4)
	var healthy_texture := visual.texture
	assert_equal(tree.apply_tool(ToolMeta.ToolKind.AXE, 2), OK)
	assert_equal(tree.harvestable_state().health, 3)
	assert_equal(tree.health_stage().min_health, 2)
	assert_true(visual.texture != healthy_texture)
	var damaged_texture := visual.texture
	assert_equal(tree.apply_tool(ToolMeta.ToolKind.AXE, 2), OK)
	assert_equal(tree.harvestable_state().health, 1)
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
	assert_equal(first.apply_tool(ToolMeta.ToolKind.PICKAXE, 1), ERR_UNAVAILABLE)
	assert_equal(float(first_material.get_shader_parameter(&"flash_amount")), 0.0)
	assert_equal(first.apply_tool(ToolMeta.ToolKind.AXE, 1), OK)
	assert_equal(float(first_material.get_shader_parameter(&"flash_amount")), 1.0)
	assert_equal(float(second_material.get_shader_parameter(&"flash_amount")), 0.0)
	first._hit_flash_tween.custom_step(1.0)
	assert_equal(float(first_material.get_shader_parameter(&"flash_amount")), 0.0)
	var plant := _add_plant(map, &"plant_flash", Vector2i(4, 2), 6)
	var plant_material := (plant.get_node("StageVisual") as Sprite2D).material as ShaderMaterial
	assert_true(plant_material != null)
	assert_equal(plant.apply_tool(ToolMeta.ToolKind.BASKET, 1), OK)
	assert_equal(float(plant_material.get_shader_parameter(&"flash_amount")), 1.0)


func test_depleted_grass_keeps_visual_until_flash_finishes() -> void:
	var map := _make_map()
	var grass := _add_harvestable(map, &"grass_flash", &"grass", Vector2i(2, 2), 1)
	var visual := grass.get_node("StageVisual") as Sprite2D
	assert_true(visual.texture != null)
	var result := _tool(DataCatalog.get_item(&"tool_sickle") as ToolMeta).use(map, [Vector2i(2, 2)], 10) as ItemToolOutcome
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
	var basket_meta := DataCatalog.get_item(&"tool_basket") as ToolMeta
	var basket := _tool(basket_meta)
	assert_equal(basket.harvest_rejection_reason(map, Vector2i(1, 1)), &"not_mature")
	immature.plant_state().growth_days = 6
	immature.harvestable_state().health = 1
	var result := basket.use(map, [Vector2i(1, 1)], 10) as ItemToolOutcome
	assert_equal(result.error, OK)
	assert_true(result.pickup_ids.size() >= 1 and result.pickup_ids.size() <= 2)
	assert_true(map.get_cell(Vector2i(1, 1)).is_dug())
	assert_true(map.harvestable_at(Vector2i(1, 1)) == null)
	assert_equal((map.get_item(result.pickup_ids[0]) as Item).state.meta_id, &"produce_parsnip")
	assert_true(map.check_cell(Vector2i(1, 1), BaseMap.CellCondition.PLANTABLE))


func test_pickup_is_non_blocking_and_persists_while_inventory_is_full() -> void:
	var map := _make_map(CellState.CellFlag.BASE | CellState.CellFlag.DROPABLE, CellState.CellFlag.DUG)
	var pickup := _add_pickup(map, &"pickup_stone", &"material_stone", Vector2i(1, 1))
	assert_true(not map.check_cell(Vector2i(1, 1), BaseMap.CellCondition.HAS_OCCUPANT))
	assert_true(map.check_cell(Vector2i(1, 1), BaseMap.CellCondition.PLANTABLE))
	assert_true(map.check_cell(Vector2i(1, 1), BaseMap.CellCondition.DROPABLE))
	var player := _make_pickup_player()
	player.state = PlayerState.new()
	player.state.backpack_state = BackpackState.new(1, 0, 1)
	player.state.backpack_state.set_slot(&"itembar", 0, BackpackSlot.new(&"itembar_0", &"material_wood", 99))
	player.state.backpack_state.set_slot(&"inventory", 0, BackpackSlot.new(&"inventory_0", &"material_wood", 99))
	player.global_position = pickup.global_position
	assert_true(not player._process_pickup(pickup, map, 0.0))
	assert_true(map.get_item(&"pickup_stone") == pickup)

	player.state.backpack_state.get_slot(&"itembar", 0).clear()
	assert_true(player._process_pickup(pickup, map, 0.0))
	assert_equal(player.state.backpack_state.count_item(&"itembar", &"material_stone"), 1)
	assert_equal(player.state.backpack_state.count_item(&"inventory", &"material_stone"), 0)
	assert_true(map.get_item(&"pickup_stone") == null)


func test_pickup_overflows_from_itembar_to_inventory() -> void:
	var map := _make_map()
	var pickup := _add_pickup(map, &"pickup_stone_overflow", &"material_stone", Vector2i(1, 1))
	var player := _make_pickup_player()
	player.state = PlayerState.new()
	player.state.backpack_state = BackpackState.new(1, 0, 1)
	player.state.backpack_state.set_slot(&"itembar", 0, BackpackSlot.new(&"itembar_0", &"material_wood", 99))
	player.global_position = pickup.global_position
	assert_true(player._process_pickup(pickup, map, 0.0))
	assert_equal(player.state.backpack_state.count_item(&"itembar", &"material_stone"), 0)
	assert_equal(player.state.backpack_state.count_item(&"inventory", &"material_stone"), 1)


func test_pickup_state_round_trip_and_cell_sync() -> void:
	var map := _make_map()
	var pickup := _add_pickup(map, &"pickup_wood", &"material_wood", Vector2i(0, 0))
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
	var pickup := _add_pickup(map, &"pickup_wood_partial", &"material_wood", Vector2i(1, 1))
	var player := _make_pickup_player()
	player.state = PlayerState.new()
	player.state.backpack_state = BackpackState.new(1, 0, 1)
	player.state.backpack_state.set_slot(&"itembar", 0, BackpackSlot.new(&"itembar_0", &"material_wood", 97))
	player.state.backpack_state.set_slot(&"inventory", 0, BackpackSlot.new(&"inventory_0", &"material_stone", 99))
	player.global_position = pickup.global_position
	assert_true(player._process_pickup(pickup, map, 0.0))
	assert_equal(player.state.backpack_state.count_item(&"itembar", &"material_wood"), 98)
	assert_equal(player.state.backpack_state.count_item(&"inventory", &"material_wood"), 0)
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
	var near := _add_pickup(map, &"pickup_near", &"material_stone", Vector2i(1, 1))
	var far := _add_pickup(map, &"pickup_far", &"material_wood", Vector2i(4, 4))
	_add_harvestable(map, &"grass_near", &"grass", Vector2i(1, 2), 1)
	var center := near.global_position
	var found := map.pickup_items_in_radius(center, 40.0)
	assert_equal(found, [near])
	assert_true(far not in found)


func test_player_moves_pickup_before_collecting_and_map_only_deletes_after_success() -> void:
	var map := _make_map()
	var pickup := _add_pickup(map, &"pickup_moving", &"material_stone", Vector2i(2, 1))
	var player := _make_pickup_player()
	player.state = PlayerState.new()
	player.global_position = pickup.global_position + Vector2(40.0, 0.0)
	var before := pickup.global_position
	assert_true(not player._process_pickup(pickup, map, 0.05))
	assert_true(pickup.global_position.distance_to(player.global_position) < before.distance_to(player.global_position))
	assert_true(map.get_item(&"pickup_moving") == pickup)


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
	var pickup_id := map.spawn_pickup(&"material_stone", Vector2i(11, 8))
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
	state.meta_id = &"crop_parsnip"
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
	var player := FarmPlayer.new()
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
