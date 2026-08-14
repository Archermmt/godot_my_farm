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
	assert_equal(Tool.item_rejection_reason(axe_meta, map, Vector2i(1, 1)), &"wrong_tool")
	assert_equal(Tool.perform(axe_meta, map, [Vector2i(1, 1)], 10).error, ERR_UNAVAILABLE)
	assert_equal((map.get_item(&"rock_a") as Harvestable).harvestable_state().health, 3)

	var pickaxe_meta := DataCatalog.get_item(&"tool_pickaxe") as ToolMeta
	var result := Tool.perform(pickaxe_meta, map, [Vector2i(1, 1), Vector2i(1, 1)], 10)
	assert_equal(result.error, OK)
	assert_equal(result.stamina_spent, pickaxe_meta.base_stamina_cost)
	assert_equal(result.effect_cells, [Vector2i(1, 1)])
	assert_equal((map.get_item(&"rock_a") as Harvestable).harvestable_state().health, 2)
	assert_equal(result.skipped_reasons[Vector2i(1, 1)], &"duplicate")


func test_death_drops_once_and_tree_becomes_stump() -> void:
	var map := _make_map()
	map.drop_rng.seed = 77
	_add_harvestable(map, &"tree_a", &"tree", Vector2i(2, 2), 1)
	var result := Tool.perform(DataCatalog.get_item(&"tool_axe") as ToolMeta, map, [Vector2i(2, 2)], 10, Vector2i(1, 2)) as ItemToolOutcome
	assert_equal(result.error, OK)
	assert_true(map.get_item(&"tree_a") == null)
	assert_equal(result.destroyed_item_ids, [&"tree_a"])
	assert_true(result.pickup_ids.size() >= 2 and result.pickup_ids.size() <= 4)
	assert_equal(result.tree_fall_directions[&"tree_a"], 1)
	var stump := map.harvestable_at(Vector2i(2, 2))
	assert_true(stump != null)
	assert_equal(stump.meta.id, &"stump")
	assert_equal(map.resolve_depleted_item(&"tree_a"), [])
	assert_equal(_pickup_count(map), result.pickup_ids.size())
	stump.harvestable_state().health = 1
	var stump_result := Tool.perform(DataCatalog.get_item(&"tool_axe") as ToolMeta, map, [Vector2i(2, 2)], 10)
	assert_equal(stump_result.error, OK)
	assert_true(map.harvestable_at(Vector2i(2, 2)) == null)
	assert_equal(_pickup_count(map), result.pickup_ids.size())


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

func test_mature_plant_harvest_preserves_dug_and_immature_is_rejected() -> void:
	var map := _make_map(CellState.CellFlag.BASE | CellState.CellFlag.DROPABLE, CellState.CellFlag.DUG)
	var immature := _add_plant(map, &"parsnip_a", Vector2i(1, 1), 0)
	assert_true(map.check_cell(Vector2i(1, 1), BaseMap.CellCondition.HAS_OCCUPANT))
	var basket_meta := DataCatalog.get_item(&"tool_basket") as ToolMeta
	assert_equal(Tool.item_rejection_reason(basket_meta, map, Vector2i(1, 1)), &"not_mature")
	immature.plant_state().growth_days = 6
	immature.harvestable_state().health = 1
	var result := Tool.perform(basket_meta, map, [Vector2i(1, 1)], 10) as ItemToolOutcome
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
	var player := FarmPlayer.new()
	_nodes.append(player)
	player.state = PlayerState.new()
	player.state.itembar = ItembarState.new(1)
	player.state.itembar.set_slot(0, ItemStack.new(&"material_wood", 99))
	player.state.inventory = InventoryState.new(1)
	player.state.inventory.set_slot(0, ItemStack.new(&"material_wood", 99))
	player.global_position = pickup.global_position
	assert_true(not pickup.attract_to(player, 0.0))
	assert_true(map.get_item(&"pickup_stone") == pickup)

	player.state.itembar.get_slot(0).clear()
	assert_true(pickup.attract_to(player, 0.0))
	assert_equal(player.state.itembar.count_item(&"material_stone"), 1)
	assert_equal(player.state.inventory.count_item(&"material_stone"), 0)
	assert_true(map.get_item(&"pickup_stone") == null)


func test_pickup_overflows_from_itembar_to_inventory() -> void:
	var map := _make_map()
	var pickup := _add_pickup(map, &"pickup_stone_overflow", &"material_stone", Vector2i(1, 1))
	var player := FarmPlayer.new()
	_nodes.append(player)
	player.state = PlayerState.new()
	player.state.itembar = ItembarState.new(1)
	player.state.itembar.set_slot(0, ItemStack.new(&"material_wood", 99))
	player.state.inventory = InventoryState.new(1)
	player.global_position = pickup.global_position
	assert_true(pickup.attract_to(player, 0.0))
	assert_equal(player.state.itembar.count_item(&"material_stone"), 0)
	assert_equal(player.state.inventory.count_item(&"material_stone"), 1)


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
	var player := FarmPlayer.new()
	_nodes.append(player)
	player.state = PlayerState.new()
	player.state.itembar = ItembarState.new(1)
	player.state.itembar.set_slot(0, ItemStack.new(&"material_wood", 97))
	player.state.inventory = InventoryState.new(1)
	player.state.inventory.set_slot(0, ItemStack.new(&"material_stone", 99))
	player.global_position = pickup.global_position
	assert_true(pickup.attract_to(player, 0.0))
	assert_equal(player.state.itembar.count_item(&"material_wood"), 98)
	assert_equal(player.state.inventory.count_item(&"material_wood"), 0)
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


func test_new_game_farm_generation_populates_runtime_hosts() -> void:
	var game_manager := GameManagerService.new()
	_nodes.append(game_manager)
	game_manager.configure(DataCatalog, null)
	assert_equal(game_manager.new_game(31415), OK)
	var map := (load("res://scenes/maps/farm/farm.tscn") as PackedScene).instantiate() as BaseMap
	_nodes.append(map)
	(Engine.get_main_loop() as SceneTree).root.add_child(map)
	map.configure_services(DataCatalog, null)
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
	map.configure_services(DataCatalog, null)
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


func _pickup_count(map: BaseMap) -> int:
	var count := 0
	for item: Item in map.items.values():
		if item != null and item.meta != null and item.meta.can_pickup:
			count += 1
	return count
