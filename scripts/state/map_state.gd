class_name MapState
extends RefCounted

var map_id: StringName = &"farm"
var generator_initialized: bool = false
var cells: Dictionary[Vector2i, CellState] = {}
var entities: Dictionary[StringName, EntityState] = {}


func to_dict() -> Dictionary:
	var cell_data: Array[Dictionary] = []
	for key: Vector2i in cells:
		cell_data.append(cells[key].to_dict())
	var entity_data: Array[Dictionary] = []
	var entity_ids: Array[StringName] = []
	entity_ids.assign(entities.keys())
	entity_ids.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	for entity_id: StringName in entity_ids:
		entity_data.append(entities[entity_id].to_dict())
	return {
		"map_id": String(map_id),
		"generator_initialized": generator_initialized,
		"cells": cell_data,
		"entities": entity_data,
	}


static func from_dict(data: Dictionary) -> MapState:
	if not SerializationUtil.has_valid_string(data, "map_id") or not SerializationUtil.has_valid_bool(data, "generator_initialized"):
		return null
	if not SerializationUtil.has_valid_array(data, "cells") or not SerializationUtil.has_valid_array(data, "entities"):
		return null
	if StringName(str(data.get("map_id", ""))) == &"":
		return null
	var restored := MapState.new()
	restored.map_id = StringName(str(data.get("map_id", "farm")))
	restored.generator_initialized = bool(data.get("generator_initialized", false))
	for raw_entity: Variant in data.get("entities", []) as Array:
		if typeof(raw_entity) != TYPE_DICTIONARY:
			return null
		var entity := EntityState.from_dict(raw_entity as Dictionary)
		if entity == null or restored.entities.has(entity.instance_id):
			return null
		restored.entities[entity.instance_id] = entity
	for raw_cell: Variant in data.get("cells", []) as Array:
		if typeof(raw_cell) != TYPE_DICTIONARY:
			return null
		var cell := CellState.from_dict(raw_cell as Dictionary)
		if cell == null or restored.cells.has(cell.cell):
			return null
		restored.cells[cell.cell] = cell
	return restored
