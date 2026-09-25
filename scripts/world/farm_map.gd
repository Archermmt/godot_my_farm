class_name FarmMap
extends BaseMap

const TERRAIN_SOURCE := 0
const GRASS := Vector2i(0, 0)
const DIRT_PATH := Vector2i(4, 1)
const SHORE := Vector2i(2, 0)
const WATER := Vector2i(3, 0)
const FARM_BED := Rect2i(3, 10, 19, 12)
const POND_RECT := Rect2i(4, 2, 9, 7)

@onready var base_layer: TileMapLayer = $TileMaps/BaseLayer
@onready var diggable_layer: TileMapLayer = $TileMaps/DiggableLayer
@onready var road_layer: TileMapLayer = $TileMaps/RoadLayer
@onready var pond_layer: TileMapLayer = $TileMaps/PondLayer


func _ready() -> void:
	super._ready()
	_build_farm_layout()


func _build_farm_layout() -> void:
	if base_layer == null or diggable_layer == null or road_layer == null or pond_layer == null:
		return
	# Keep the playable footprint while laying out the compact central crop plot.
	diggable_layer.clear()
	for y in range(FARM_BED.position.y, FARM_BED.end.y):
		for x in range(FARM_BED.position.x, FARM_BED.end.x):
			var cell := Vector2i(x, y)
			diggable_layer.set_cell(cell, TERRAIN_SOURCE, Vector2i(1, 0), 0)

	road_layer.clear()
	for x in range(10, 38):
		_set_terrain(road_layer, Vector2i(x, 9), DIRT_PATH)
	for y in range(7, 28):
		_set_terrain(road_layer, Vector2i(23, y), DIRT_PATH)
	for x in range(3, 22):
		_set_terrain(road_layer, Vector2i(x, 23), DIRT_PATH)

	pond_layer.clear()
	for y in range(POND_RECT.position.y - 1, POND_RECT.end.y + 1):
		for x in range(POND_RECT.position.x - 1, POND_RECT.end.x + 1):
			var cell := Vector2i(x, y)
			var is_edge := x == POND_RECT.position.x - 1 or x == POND_RECT.end.x or y == POND_RECT.position.y - 1 or y == POND_RECT.end.y
			_set_terrain(pond_layer, cell, SHORE if is_edge else WATER)
	
	$House.position = Vector2(640, 32)
	$StaticCollision/Pond.position = Vector2(272, 176)
	$SpawnPoints/default.position = Vector2(384, 320)
	$SpawnPoints/wake.position = Vector2(768, 128)


func _set_terrain(layer: TileMapLayer, cell: Vector2i, atlas: Vector2i) -> void:
	if has_static_cell(cell):
		layer.set_cell(cell, TERRAIN_SOURCE, atlas, 0)
