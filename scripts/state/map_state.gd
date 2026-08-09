class_name MapState
extends RefCounted

var map_id: StringName = &"farm"
var generator_initialized: bool = false
var cells: Dictionary[Vector2i, CellState] = {}


func set_cell(state: CellState) -> Error:
	if state == null:
		return ERR_INVALID_PARAMETER
	var existing := cells.get(state.cell, null) as CellState
	for entity_id: StringName in state.entities:
		var entity: EntityState = state.entities[entity_id]
		if entity == null or entity.instance_id != entity_id or entity.cell != state.cell:
			return ERR_INVALID_DATA
		var owner := get_entity_cell(entity_id)
		if owner != null and owner != existing:
			return ERR_ALREADY_EXISTS
	cells[state.cell] = state
	return OK


func set_entity(state: EntityState) -> Error:
	if state == null or state.instance_id == &"":
		return ERR_INVALID_PARAMETER
	if get_entity_cell(state.instance_id) != null:
		return ERR_ALREADY_EXISTS
	var cell_state := cells.get(state.cell, null) as CellState
	if cell_state == null:
		return ERR_DOES_NOT_EXIST
	return cell_state.add_entity(state)


func get_entity(entity_id: StringName) -> EntityState:
	var cell_state := get_entity_cell(entity_id)
	return cell_state.get_entity(entity_id) if cell_state != null else null


func get_entity_cell(entity_id: StringName) -> CellState:
	for cell_state: CellState in cells.values():
		if cell_state.has_entity(entity_id):
			return cell_state
	return null


func remove_entity(entity_id: StringName) -> Error:
	var cell_state := get_entity_cell(entity_id)
	if cell_state == null:
		return ERR_DOES_NOT_EXIST
	return cell_state.remove_entity(entity_id)


func move_entity(entity_id: StringName, target_cell: Vector2i) -> Error:
	var source := get_entity_cell(entity_id)
	var target := cells.get(target_cell, null) as CellState
	if source == null:
		return ERR_DOES_NOT_EXIST
	if target == null:
		return ERR_INVALID_PARAMETER
	if source == target:
		return OK
	if target.has_entity(entity_id):
		return ERR_ALREADY_EXISTS
	var entity := source.get_entity(entity_id)
	var previous_cell := entity.cell
	var remove_error := source.remove_entity(entity_id)
	if remove_error != OK:
		return remove_error
	entity.cell = target_cell
	var add_error := target.add_entity(entity)
	if add_error != OK:
		entity.cell = previous_cell
		var rollback_error := source.add_entity(entity)
		assert(rollback_error == OK)
		return add_error
	return OK


func to_dict() -> Dictionary:
	var cell_data: Array[Dictionary] = []
	for key: Vector2i in cells:
		var cell_state: CellState = cells[key]
		cell_data.append(cell_state.to_dict())
	return {
		"map_id": String(map_id),
		"generator_initialized": generator_initialized,
		"cells": cell_data,
	}


static func from_dict(data: Dictionary) -> MapState:
	if not SerializationUtil.has_valid_string(data, "map_id") or not SerializationUtil.has_valid_bool(data, "generator_initialized"):
		return null
	if not SerializationUtil.has_valid_array(data, "cells"):
		return null
	if StringName(str(data.get("map_id", ""))) == &"":
		return null
	var restored := MapState.new()
	restored.map_id = StringName(str(data.get("map_id", "farm")))
	restored.generator_initialized = bool(data.get("generator_initialized", false))
	for raw_cell: Variant in data.get("cells", []) as Array:
		if typeof(raw_cell) != TYPE_DICTIONARY:
			return null
		var cell_state := CellState.from_dict(raw_cell as Dictionary)
		if cell_state == null or restored.cells.has(cell_state.cell):
			return null
		if restored.set_cell(cell_state) != OK:
			return null
	var seen_entity_ids: Dictionary[StringName, bool] = {}
	for cell_state: CellState in restored.cells.values():
		for entity_id: StringName in cell_state.entities:
			if seen_entity_ids.has(entity_id):
				return null
			seen_entity_ids[entity_id] = true
	return restored
