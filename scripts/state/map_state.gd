class_name MapState
extends RefCounted

var map_id: StringName = &"farm"
var generator_initialized: bool = false
var generation_epoch: int = 0
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
		item_data.append(ItemCodec.to_dict(items[item_id]))
	return {
		"map_id": String(map_id),
		"generator_initialized": generator_initialized,
		"generation_epoch": generation_epoch,
		"cells": cell_data,
		"items": item_data,
	}


static func from_dict(data: Dictionary) -> MapState:
	if not SerializationUtil.has_valid_string(data, "map_id") or not SerializationUtil.has_valid_bool(data, "generator_initialized") or not SerializationUtil.has_valid_int(data, "generation_epoch"):
		return null
	if not SerializationUtil.has_valid_array(data, "cells") or not SerializationUtil.has_valid_array(data, "items"):
		return null
	if StringName(str(data.get("map_id", ""))) == &"":
		return null
	var restored := MapState.new()
	restored.map_id = StringName(str(data.get("map_id", "farm")))
	restored.generator_initialized = bool(data.get("generator_initialized", false))
	restored.generation_epoch = int(data.get("generation_epoch", 0))
	if restored.generation_epoch < 0:
		return null
	for raw_item: Variant in data.get("items", []) as Array:
		if typeof(raw_item) != TYPE_DICTIONARY:
			return null
		var item := ItemCodec.from_dict(raw_item as Dictionary)
		if item == null or restored.items.has(item.unique_id):
			return null
		restored.items[item.unique_id] = item
	for raw_cell: Variant in data.get("cells", []) as Array:
		if typeof(raw_cell) != TYPE_DICTIONARY:
			return null
		var cell := CellState.from_dict(raw_cell as Dictionary)
		if cell == null or restored.cells.has(cell.cell):
			return null
		restored.cells[cell.cell] = cell
	return restored
