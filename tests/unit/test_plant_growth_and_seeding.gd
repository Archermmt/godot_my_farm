extends ProjectTestCase

func test_seed_only_plants_dug_empty_cells_and_consumes_targets() -> void:
	var map := _make_map()
	var state := MapState.new()
	state.map_id = &"farm"
	assert_equal(map.configure_state(state), ERR_UNCONFIGURED)
	map.get_cell(Vector2i(1, 1)).add_state_flag(CellState.CellFlag.DUG)
	map.get_cell(Vector2i(2, 1)).add_state_flag(CellState.CellFlag.DUG)
	map.commit_cell_changes([Vector2i(1, 1), Vector2i(2, 1)])
	var seed := Seed.new(DataCatalog.get_seed(&"parsnip_seed"))
	var result := seed.use(map, [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 1)], 1, 2)
	assert_equal(result.error, ERR_UNAVAILABLE)
	assert_equal(map.item_count(), 0)
	var valid := seed.use(map, [Vector2i(1, 1), Vector2i(2, 1)], 1, 2)
	assert_true(valid.succeeded())
	assert_equal(valid.consumed_count(), 2)
	assert_equal(map.item_count(), 2)
	assert_true(map.get_cell(Vector2i(1, 1)).has_occupant())
	seed.free()
	map.free()


func test_growth_uses_meta_thresholds_and_water_is_idempotent() -> void:
	var map := _make_map()
	var state := MapState.new()
	state.map_id = &"farm"
	assert_equal(map.configure_state(state), ERR_UNCONFIGURED)
	var cell := map.get_cell(Vector2i(1, 1))
	cell.add_state_flag(CellState.CellFlag.DUG | CellState.CellFlag.WATERED)
	map.commit_cell_changes([Vector2i(1, 1)])
	var seed := Seed.new(DataCatalog.get_seed(&"parsnip_seed"))
	var planted := seed.use(map, [Vector2i(1, 1)], 1, 1)
	assert_true(planted.succeeded())
	var planted_ids := cell.cell_state().item_ids
	assert_equal(planted_ids.size(), 1)
	var plant := map.get_item(planted_ids[0]) as Plant
	assert_equal(plant.stage_index(), 0)
	assert_equal(map.settle_day(2).size(), 1)
	assert_equal(plant.plant_state().growth_days, 1)
	assert_equal(plant.stage_index(), 0)
	assert_true(not cell.is_watered())
	var repeated := map.settle_day(2)
	assert_equal(repeated.size(), 0)
	assert_equal(plant.plant_state().growth_days, 1)
	cell.add_state_flag(CellState.CellFlag.WATERED)
	map.settle_day(3)
	assert_equal(plant.plant_state().growth_days, 2)
	assert_equal(plant.stage_index(), 1)
	plant.plant_state().growth_days = 6
	assert_true(plant.is_mature())
	assert_true(plant.is_harvestable())
	seed.free()
	map.free()


func test_plant_state_round_trip_preserves_stage_and_instance_id() -> void:
	var plant := PlantState.new()
	plant.instance_id = &"parsnip_7"
	plant.meta_id = &"parsnip"
	plant.growth_days = 4
	plant.planted_on_day = 1
	plant.last_growth_day = 8
	var restored := ItemCodec.from_dict(JSON.parse_string(JSON.stringify(ItemCodec.to_dict(plant))) as Dictionary) as PlantState
	assert_true(restored != null)
	assert_equal(restored.instance_id, plant.instance_id)
	assert_equal(restored.growth_days, 4)
	assert_equal(restored.last_growth_day, 8)


func _make_map() -> BaseMap:
	var map := BaseMap.new()
	map.map_id = &"farm"
	var host := Node2D.new()
	host.name = "Plants"
	map.add_child(host)
	map.plants_host = host
	for y: int in 3:
		for x: int in 3:
			map.cells[Vector2i(x, y)] = MapCell.new(Vector2i(x, y), CellState.CellFlag.BASE | CellState.CellFlag.DROPABLE)
	return map
