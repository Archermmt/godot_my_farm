extends SceneTree

## Configure TileSetAtlasSource animation data in one pass.
## Run with: godot --headless --path . --script res://tools/configure_tileset_animation.gd

const SCENE_PATH := "res://scenes/maps/test/test.tscn"
const TILEMAP_LAYER_PATH := NodePath("terrain")
const SOURCE_ID := 1

## Add every atlas tile that should receive the same animation settings.
const TILE_COORDS: Array[Vector2i] = [
	Vector2i(0, 5),
	Vector2i(1, 5),
	Vector2i(2, 5),
]

const ANIMATION_COLUMNS := 4
const ANIMATION_SEPARATION := Vector2i(2, 0)
const ANIMATION_SPEED := 8.0
const FRAME_DURATION := 1.0


func _init() -> void:
	var packed_scene := load(SCENE_PATH) as PackedScene
	if packed_scene == null:
		push_error("Could not load scene: %s" % SCENE_PATH)
		quit(1)
		return

	var root := packed_scene.instantiate()
	var layer := root.get_node_or_null(TILEMAP_LAYER_PATH) as TileMapLayer
	if layer == null:
		push_error("TileMapLayer not found: %s" % TILEMAP_LAYER_PATH)
		root.free()
		quit(1)
		return

	var tile_set := layer.tile_set
	if tile_set == null or not tile_set.has_source(SOURCE_ID):
		push_error("TileSet source %d not found on %s" % [SOURCE_ID, TILEMAP_LAYER_PATH])
		root.free()
		quit(1)
		return

	var source := tile_set.get_source(SOURCE_ID) as TileSetAtlasSource
	if source == null:
		push_error("Source %d is not a TileSetAtlasSource" % SOURCE_ID)
		root.free()
		quit(1)
		return

	for atlas_coords in TILE_COORDS:
		_configure_tile(source, atlas_coords)

	var output := PackedScene.new()
	var pack_error := output.pack(root)
	root.free()
	if pack_error != OK:
		push_error("Could not pack scene: %s" % error_string(pack_error))
		quit(1)
		return

	var save_error := ResourceSaver.save(output, SCENE_PATH)
	if save_error != OK:
		push_error("Could not save scene: %s" % error_string(save_error))
		quit(1)
		return

	print("Configured %d tile(s): %s" % [TILE_COORDS.size(), SCENE_PATH])
	quit(0)


func _configure_tile(source: TileSetAtlasSource, atlas_coords: Vector2i) -> void:
	if not source.has_tile(atlas_coords):
		source.create_tile(atlas_coords)

	_clear_animation_slots(source, atlas_coords)
	source.set_tile_animation_separation(atlas_coords, ANIMATION_SEPARATION)
	source.set_tile_animation_columns(atlas_coords, ANIMATION_COLUMNS)

	# The frame count is deliberately set before durations. This replaces the
	# Inspector's repeated "Add Element" action with one deterministic update.
	source.set_tile_animation_frames_count(atlas_coords, ANIMATION_COLUMNS)
	source.set_tile_animation_speed(atlas_coords, ANIMATION_SPEED)
	for frame in ANIMATION_COLUMNS:
		source.set_tile_animation_frame_duration(atlas_coords, frame, FRAME_DURATION)


func _clear_animation_slots(source: TileSetAtlasSource, atlas_coords: Vector2i) -> void:
	var tile_size := source.get_tile_size_in_atlas(atlas_coords)
	var slots: Array[Rect2i] = []
	for frame in ANIMATION_COLUMNS:
		var frame_coords := atlas_coords + ANIMATION_SEPARATION * frame
		slots.append(Rect2i(frame_coords, tile_size))

	var remove_coords: Array[Vector2i] = []
	for index in source.get_tiles_count():
		var candidate := source.get_tile_id(index)
		if candidate == atlas_coords:
			continue
		var candidate_rect := Rect2i(candidate, source.get_tile_size_in_atlas(candidate))
		for slot in slots:
			if candidate_rect.intersects(slot):
				remove_coords.append(candidate)
				break
	for candidate in remove_coords:
		source.remove_tile(candidate)
