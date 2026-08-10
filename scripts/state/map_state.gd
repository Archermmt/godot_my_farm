class_name MapState
extends RefCounted

var map_id: StringName = &"farm"
var generator_initialized: bool = false
var cells: Dictionary[Vector2i, CellState] = {}
var items: Dictionary[StringName, ItemState] = {}


func to_dict() -> Dictionary:
	var cell_data: Array[Dictionary] = []
	for key: Vector2i in cells:
		cell_data.append(cells[key].to_dict())
	var item_data: Array[Dictionary] = []
	var item_ids: Array[StringName] = []
	item_ids.assign(items.keys())
	item_ids.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	for item_id: StringName in item_ids:
		item_data.append(items[item_id].to_dict())
	return {
		"map_id": String(map_id),
		"generator_initialized": generator_initialized,
		"cells": cell_data,
		"items": item_data,
	}


static func from_dict(data: Dictionary) -> MapState:
	if not SerializationUtil.has_valid_string(data, "map_id") or not SerializationUtil.has_valid_bool(data, "generator_initialized"):
		return null
	if not SerializationUtil.has_valid_array(data, "cells") or not SerializationUtil.has_valid_array(data, "items"):
		return null
	if StringName(str(data.get("map_id", ""))) == &"":
		return null
	var restored := MapState.new()
	restored.map_id = StringName(str(data.get("map_id", "farm")))
	restored.generator_initialized = bool(data.get("generator_initialized", false))
	for raw_item: Variant in data.get("items", []) as Array:
		if typeof(raw_item) != TYPE_DICTIONARY:
			return null
		var item := ItemState.from_dict(raw_item as Dictionary)
		if item == null or restored.items.has(item.instance_id):
			return null
		restored.items[item.instance_id] = item
	for raw_cell: Variant in data.get("cells", []) as Array:
		if typeof(raw_cell) != TYPE_DICTIONARY:
			return null
		var cell := CellState.from_dict(raw_cell as Dictionary)
		if cell == null or restored.cells.has(cell.cell):
			return null
		restored.cells[cell.cell] = cell
	return restored
