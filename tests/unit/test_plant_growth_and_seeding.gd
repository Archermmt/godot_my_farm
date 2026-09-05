extends ProjectTestCase

func test_seed_skips_occupied_cells_and_stops_at_available_count() -> void:
	var map := _make_map()
	var state := MapState.new()
	state.map_id = &"farm"
	assert_equal(map.setup(state), ERR_UNCONFIGURED)
	map.get_cell(Vector2i(0, 0)).add_flag(CellState.CellFlag.DUG)
	map.get_cell(Vector2i(1, 1)).add_flag(CellState.CellFlag.DUG)
	map.get_cell(Vector2i(2, 1)).add_flag(CellState.CellFlag.DUG)
	map.get_cell(Vector2i(0, 0)).add_item_id(&"occupied")
	map.rebuild_layers()
	var seed := _test_seed(DataCatalog.get_item(&"parsnip_seed") as SeedMeta)
	var result := seed.use(map, [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 1)], 1)
	assert_true(result.succeeded())
	assert_equal(result.cells.size(), 1)
	assert_equal(result.cells[0], Vector2i(1, 1))
	assert_equal(map.items.size(), 1)
	assert_true(map.get_cell(Vector2i(1, 1)).has_occupant())
	assert_true(not map.get_cell(Vector2i(2, 1)).has_occupant())
	seed.free()
	map.free()


func test_growth_uses_meta_thresholds_and_water_is_idempotent() -> void:
	var map := _make_map()
	var state := MapState.new()
	state.map_id = &"farm"
	assert_equal(map.setup(state), ERR_UNCONFIGURED)
	var cell := map.get_cell(Vector2i(1, 1))
	cell.add_flag(CellState.CellFlag.DUG | CellState.CellFlag.WATERED)
	map.rebuild_layers()
	var seed := _test_seed(DataCatalog.get_item(&"parsnip_seed") as SeedMeta)
	var planted := seed.use(map, [Vector2i(1, 1)], 1)
	assert_true(planted.succeeded())
	var planted_ids := cell.state.item_ids
	assert_equal(planted_ids.size(), 1)
	var plant := map.get_item(planted_ids[0]) as Plant
	assert_equal(plant.stage_index(), 0)
	map._on_day_advanced()
	assert_equal(plant.state.health, 2)
	assert_equal(plant.stage_index(), 0)
	assert_true(not map.check_cell(cell.coordinates, CellState.CellCondition.WATERED))
	map._on_day_advanced()
	assert_equal(plant.state.health, 2)
	cell.add_flag(CellState.CellFlag.WATERED)
	map._on_day_advanced()
	assert_equal(plant.state.health, 3)
	assert_equal(plant.stage_index(), 1)
	plant.state.health = (plant.meta as PlantMeta).health
	assert_true(plant.is_mature())
	seed.free()
	map.free()


func test_plant_state_round_trip_preserves_stage_and_unique_id() -> void:
	var plant := PlantState.new()
	plant.unique_id = &"parsnip_7"
	plant.meta_id = &"parsnip"
	plant.last_growth_day = 8
	var restored := ItemCodec.from_dict(JSON.parse_string(JSON.stringify(ItemCodec.to_dict(plant))) as Dictionary) as PlantState
	assert_true(restored != null)
	assert_equal(restored.unique_id, plant.unique_id)
	assert_equal(restored.last_growth_day, 8)


func _make_map() -> BaseMap:
	var map := BaseMap.new()
	map.map_id = &"farm"
	var host := Node2D.new()
	host.name = "Plants"
	map.add_child(host)
	map.item_hosts[ItemMeta.ItemType.PLANT] = host
	for y: int in 3:
		for x: int in 3:
			map.cells[Vector2i(x, y)] = MapCell.new(Vector2i(x, y), _state(CellState.CellFlag.BASE | CellState.CellFlag.DROPABLE))
	return map


func _test_seed(item_meta: SeedMeta) -> Seed:
	var item_state := ItemState.new()
	item_state.unique_id = StringName("test_%s" % item_meta.id)
	item_state.meta_id = item_meta.id
	return Seed.new(item_state)


func _state(flags: int) -> CellState:
	var result := CellState.new()
	result.flags = flags
	return result
