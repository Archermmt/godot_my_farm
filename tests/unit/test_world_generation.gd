extends ProjectTestCase

const FARM_SCENE := preload("res://scenes/maps/farm/farm.tscn")
const FIELD_SCENE := preload("res://scenes/maps/field/field.tscn")

var _nodes: Array[Node] = []


func after_each() -> void:
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


func test_generation_is_seeded_and_respects_cell_and_safe_zone_constraints() -> void:
	var first_state := MapState.new()
	first_state.map_id = &"farm"
	var first := _farm()
	assert_equal(first.configure_state(first_state, 7301, true), OK)
	var first_layout := _layout(first_state)
	assert_true(first_state.generator_initialized)
	assert_true(not first_layout.is_empty())
	assert_equal(int(first.last_generation_summary["spawned"]), first_state.items.size())
	for item_state: ItemState in first_state.items.values():
		assert_true(Rect2i(Vector2i.ZERO, first.get_map_size()).has_point(item_state.cell))
		var cell := first.get_cell(item_state.cell)
		assert_true(cell.has_static_flag(CellState.CellFlag.BASE))
		for flag: CellState.CellFlag in first.items_generator.forbidden_flags:
			assert_true(not cell.has_static_flag(flag))
		assert_true(&"generated" in item_state.flags)
		assert_true(not _inside_safe_zone(first, item_state.cell, first.items_generator.safe_radius))

	var same_state := MapState.new()
	same_state.map_id = &"farm"
	var same := _farm()
	assert_equal(same.configure_state(same_state, 7301, true), OK)
	assert_equal(_layout(same_state), first_layout)

	var different_state := MapState.new()
	different_state.map_id = &"farm"
	var different := _farm()
	assert_equal(different.configure_state(different_state, 7302, true), OK)
	assert_true(_layout(different_state) != first_layout)


func test_generation_runs_once_across_twenty_map_restores() -> void:
	var state := MapState.new()
	state.map_id = &"farm"
	var first := _farm()
	assert_equal(first.configure_state(state, 8080, true), OK)
	var expected_ids := _sorted_ids(state)
	assert_true(not expected_ids.is_empty())
	_nodes.erase(first)
	first.free()

	for _iteration: int in 20:
		var restored := _farm()
		assert_equal(restored.configure_state(state, 8080, true), OK)
		assert_equal(_sorted_ids(state), expected_ids)
		assert_equal(restored.items.size(), expected_ids.size())
		_nodes.erase(restored)
		restored.free()


func test_generated_and_manual_item_state_survive_snapshot_restore() -> void:
	var state := MapState.new()
	state.map_id = &"farm"
	var map := _farm()
	assert_equal(map.configure_state(state, 991, true), OK)
	var removed_id: StringName = _sorted_ids(state)[0]
	assert_equal(map.remove_item(removed_id), OK)
	var changed_id: StringName = _sorted_ids(state)[0]
	var changed := state.items[changed_id] as HarvestableState
	changed.health = 1

	var pickup := ItemState.new()
	pickup.instance_id = &"manual_wood"
	pickup.meta_id = &"material_wood"
	var pickup_cell := _empty_cell(map)
	assert_equal(map.add_item_state(pickup, pickup_cell), OK)
	var plant := PlantState.new()
	plant.instance_id = &"manual_parsnip"
	plant.meta_id = &"crop_parsnip"
	plant.health = 1
	plant.growth_days = 2
	plant.planted_on_day = 1
	var plant_cell := _empty_cell(map)
	assert_equal(map.add_item_state(plant, plant_cell), OK)

	var restored_state := MapState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())) as Dictionary)
	assert_true(restored_state != null)
	var restored := _farm()
	assert_equal(restored.configure_state(restored_state, 991, true), OK)
	assert_true(not restored_state.items.has(removed_id))
	assert_equal((restored_state.items[changed_id] as HarvestableState).health, 1)
	assert_true(restored_state.items[&"manual_wood"] is ItemState)
	assert_true(restored_state.items[&"manual_parsnip"] is PlantState)
	assert_equal((restored_state.items[&"manual_parsnip"] as PlantState).growth_days, 2)


func test_no_valid_cells_finishes_without_attempt_loop() -> void:
	var state := MapState.new()
	state.map_id = &"farm"
	var map := _farm()
	for cell: MapCell in map.cells.values():
		cell.add_static_flag(CellState.CellFlag.BLOCKED)
	assert_equal(map.configure_state(state, 77, true), OK)
	assert_true(state.generator_initialized)
	assert_equal(int(map.last_generation_summary["spawned"]), 0)
	assert_equal(int(map.last_generation_summary["attempts"]), 0)
	assert_equal(int(map.last_generation_summary["skipped"]), int(map.last_generation_summary["requested"]))


func test_generator_rejects_duplicate_candidate_types() -> void:
	var generator := ItemsGenerator.new()
	_nodes.append(generator)
	var first := ItemsGeneratorCandidate.new()
	first.meta_id = &"tree"
	first.max_count = 1
	var duplicate := ItemsGeneratorCandidate.new()
	duplicate.meta_id = &"tree"
	duplicate.max_count = 1
	generator.candidates = [first, duplicate]
	assert_equal(generator.validation_error(), ERR_INVALID_DATA)


func test_field_generation_uses_resource_cells_within_map_size() -> void:
	var state := MapState.new()
	state.map_id = &"field"
	var map := FIELD_SCENE.instantiate() as BaseMap
	_nodes.append(map)
	(Engine.get_main_loop() as SceneTree).root.add_child(map)
	assert_equal(map.configure_state(state, 4021, true), OK)
	assert_true(state.items.size() > 0)
	for item_state: ItemState in state.items.values():
		assert_true(Rect2i(Vector2i.ZERO, map.get_map_size()).has_point(item_state.cell))
		var cell := map.get_cell(item_state.cell)
		assert_true(cell.has_static_flag(CellState.CellFlag.BASE))
		assert_true(cell.has_static_flag(CellState.CellFlag.RESOURCE))
		for flag: CellState.CellFlag in map.items_generator.forbidden_flags:
			assert_true(not cell.has_static_flag(flag))


func test_farm_and_field_generate_loose_pickup_items() -> void:
	for map: BaseMap in [_farm(), _field()]:
		var state := MapState.new()
		state.map_id = map.map_id
		assert_equal(map.configure_state(state, 6127, true), OK)
		var loose_items := 0
		for item_state: ItemState in state.items.values():
			if item_state is HarvestableState:
				continue
			var item_meta := DataCatalog.get_item(item_state.meta_id)
			assert_true(item_meta != null and item_meta.can_pickup)
			loose_items += 1
		assert_true(loose_items > 0)


func _farm() -> BaseMap:
	var map := FARM_SCENE.instantiate() as BaseMap
	_nodes.append(map)
	(Engine.get_main_loop() as SceneTree).root.add_child(map)
	return map


func _field() -> BaseMap:
	var map := FIELD_SCENE.instantiate() as BaseMap
	_nodes.append(map)
	(Engine.get_main_loop() as SceneTree).root.add_child(map)
	return map


func _layout(state: MapState) -> Array[String]:
	var layout: Array[String] = []
	for item_state: ItemState in state.items.values():
		layout.append("%s:%d,%d" % [item_state.meta_id, item_state.cell.x, item_state.cell.y])
	layout.sort()
	return layout


func _sorted_ids(state: MapState) -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(state.items.keys())
	ids.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	return ids


func _inside_safe_zone(map: BaseMap, coordinates: Vector2i, radius: int) -> bool:
	for parent_name: String in ["SpawnPoints", "Ports"]:
		var parent := map.get_node_or_null(parent_name)
		if parent == null:
			continue
		for child: Node in parent.get_children():
			if child is Node2D:
				var center := map.world_to_cell((child as Node2D).global_position)
				if absi(coordinates.x - center.x) <= radius and absi(coordinates.y - center.y) <= radius:
					return true
	return false


func _empty_cell(map: BaseMap) -> Vector2i:
	for coordinates: Vector2i in map.cells:
		if not map.get_cell(coordinates).has_occupant():
			return coordinates
	return Vector2i(-1, -1)
