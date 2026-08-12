extends ProjectTestCase

func test_seed_only_plants_dug_empty_cells_and_consumes_targets() -> void:
	var map := _make_map()
	var state := MapState.new()
	state.map_id = &"farm"
	assert_equal(map.configure_state(state), ERR_UNCONFIGURED)
	map.get_cell(Vector2i(1, 1)).add_flag(CellState.CellFlag.DUG)
	map.get_cell(Vector2i(2, 1)).add_flag(CellState.CellFlag.DUG)
	map.commit_cell_changes([Vector2i(1, 1), Vector2i(2, 1)])
	var result := SeedItem.new(DataCatalog.get_item(&"seed_parsnip"), DataCatalog).use(map, [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 1)], 1, 2)
	assert_equal(result.error, ERR_UNAVAILABLE)
	assert_equal(map.item_count(ItemMeta.WorldType.PLANT), 0)
	var valid := SeedItem.new(DataCatalog.get_item(&"seed_parsnip"), DataCatalog).use(map, [Vector2i(1, 1), Vector2i(2, 1)], 1, 2)
	assert_true(valid.succeeded())
	assert_equal(valid.consumed_count(), 2)
	assert_equal(map.item_count(ItemMeta.WorldType.PLANT), 2)
	assert_true(map.get_cell(Vector2i(1, 1)).has_occupant())
	map.free()


func test_growth_uses_meta_thresholds_and_water_is_idempotent() -> void:
	var map := _make_map()
	var state := MapState.new()
	state.map_id = &"farm"
	assert_equal(map.configure_state(state), ERR_UNCONFIGURED)
	var cell := map.get_cell(Vector2i(1, 1))
	cell.add_flag(CellState.CellFlag.DUG | CellState.CellFlag.WATERED)
	map.commit_cell_changes([Vector2i(1, 1)])
	var planted := SeedItem.new(DataCatalog.get_item(&"seed_parsnip"), DataCatalog).use(map, [Vector2i(1, 1)], 1, 1)
	assert_true(planted.succeeded())
	var plant := map.get_item(planted.instance_ids[0]) as PlantItem
	assert_equal(plant.stage_index(), 0)
	assert_equal(map.settle_day(2).size(), 1)
	assert_equal(plant.plant_state.growth_days, 1)
	assert_equal(plant.stage_index(), 0)
	assert_true(not cell.is_watered())
	var repeated := map.settle_day(2)
	assert_equal(repeated.size(), 0)
	assert_equal(plant.plant_state.growth_days, 1)
	cell.add_flag(CellState.CellFlag.WATERED)
	map.settle_day(3)
	assert_equal(plant.plant_state.growth_days, 2)
	assert_equal(plant.stage_index(), 1)
	plant.plant_state.growth_days = 6
	assert_true(plant.is_mature())
	assert_true(plant.is_harvestable())
	map.free()


func test_plant_state_round_trip_preserves_stage_and_instance_id() -> void:
	var plant := PlantState.new()
	plant.instance_id = &"crop_parsnip_7"
	plant.meta_id = &"crop_parsnip"
	plant.cell = Vector2i(3, 4)
	plant.growth_days = 4
	plant.planted_on_day = 1
	plant.last_growth_day = 8
	var restored := PlantState.from_dict(JSON.parse_string(JSON.stringify(plant.to_dict())) as Dictionary)
	assert_true(restored != null)
	assert_equal(restored.instance_id, plant.instance_id)
	assert_equal(restored.growth_days, 4)
	assert_equal(restored.last_growth_day, 8)


func _make_map() -> BaseMap:
	var map := BaseMap.new()
	map.map_id = &"farm"
	map.configure_services(DataCatalog)
	var host := Node2D.new()
	host.name = "Plants"
	map.add_child(host)
	map.item_hosts[host] = ItemMeta.WorldType.PLANT
	for y: int in 3:
		for x: int in 3:
			map.cells[Vector2i(x, y)] = MapCell.new(Vector2i(x, y), CellState.CellFlag.BASE | CellState.CellFlag.DROPABLE)
	return map
