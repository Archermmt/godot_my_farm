class_name MapState
extends RefCounted

var map_id: StringName = &"farm"
var generator_initialized: bool = false
var farm_cells: Dictionary = {}
var spawned_entities: Dictionary = {}
var npcs: Dictionary = {}


func set_farm_cell(state: FarmCellState) -> void:
	if state == null:
		return
	farm_cells[state.cell] = state


func set_entity(state: WorldEntityState) -> void:
	if state == null or state.instance_id == &"":
		return
	spawned_entities[state.instance_id] = state


func set_npc(state: NpcState) -> void:
	if state == null or state.npc_id == &"":
		return
	npcs[state.npc_id] = state


func to_dict() -> Dictionary:
	var cell_data: Array[Dictionary] = []
	for key: Variant in farm_cells.keys():
		var cell_state: FarmCellState = farm_cells[key]
		cell_data.append(cell_state.to_dict())
	var entity_data: Array[Dictionary] = []
	for key: Variant in spawned_entities.keys():
		var entity_state: WorldEntityState = spawned_entities[key]
		entity_data.append(entity_state.to_dict())
	var npc_data: Array[Dictionary] = []
	for key: Variant in npcs.keys():
		var npc_state: NpcState = npcs[key]
		npc_data.append(npc_state.to_dict())
	return {
		"map_id": String(map_id),
		"generator_initialized": generator_initialized,
		"farm_cells": cell_data,
		"spawned_entities": entity_data,
		"npcs": npc_data,
	}


static func from_dict(data: Dictionary) -> MapState:
	if not SerializationUtil.has_valid_string(data, "map_id") or not SerializationUtil.has_valid_bool(data, "generator_initialized"):
		return null
	for key: String in ["farm_cells", "spawned_entities", "npcs"]:
		if not SerializationUtil.has_valid_array(data, key):
			return null
	if StringName(str(data.get("map_id", ""))) == &"":
		return null
	var restored := MapState.new()
	restored.map_id = StringName(str(data.get("map_id", "farm")))
	restored.generator_initialized = bool(data.get("generator_initialized", false))
	for raw_cell: Variant in data.get("farm_cells", []) as Array:
		if typeof(raw_cell) != TYPE_DICTIONARY:
			return null
		var cell_state := FarmCellState.from_dict(raw_cell as Dictionary)
		if cell_state == null or restored.farm_cells.has(cell_state.cell):
			return null
		restored.set_farm_cell(cell_state)
	for raw_entity: Variant in data.get("spawned_entities", []) as Array:
		if typeof(raw_entity) != TYPE_DICTIONARY:
			return null
		var entity_state := WorldEntityState.from_dict(raw_entity as Dictionary)
		if entity_state == null or restored.spawned_entities.has(entity_state.instance_id):
			return null
		restored.set_entity(entity_state)
	for raw_npc: Variant in data.get("npcs", []) as Array:
		if typeof(raw_npc) != TYPE_DICTIONARY:
			return null
		var npc_state := NpcState.from_dict(raw_npc as Dictionary)
		if npc_state == null or restored.npcs.has(npc_state.npc_id):
			return null
		restored.set_npc(npc_state)
	return restored
