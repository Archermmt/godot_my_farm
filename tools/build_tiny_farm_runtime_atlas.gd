extends SceneTree

const ROOT := "res://assets/art/external/tiny_farm_purchased/"
const OUT := "res://assets/art/runtime/tiny_farm/world_tiles.png"
const CHARACTER_OUT := "res://assets/art/runtime/tiny_farm/player_atlas.png"

func _init() -> void:
	var atlas := Image.create(160, 64, false, Image.FORMAT_RGBA8)
	var grass := _load("Tileset/Tileset Grass Spring.png")
	var soil := _load("Tileset/Tilled Soil and wet soil.png")
	var water := _load("Tileset/Water Ground animations tiles.png")
	var beach := _load("Tileset/Beach animations tiles.png")
	var forest := _load("Tileset/Tileset Grass Deep Forest.png")
	# Each logical 32px tile is made from four native 16px tiles. No resampling.
	_place(atlas, grass, Rect2i(80, 16, 16, 16), Vector2i(0, 0))
	_place(atlas, soil, Rect2i(128, 32, 16, 16), Vector2i(32, 0))
	_place(atlas, beach, Rect2i(192, 96, 16, 16), Vector2i(64, 0))
	_place(atlas, water, Rect2i(192, 128, 16, 16), Vector2i(96, 0))
	_place(atlas, forest, Rect2i(16, 16, 16, 16), Vector2i(128, 0))
	_place(atlas, soil, Rect2i(128, 96, 16, 16), Vector2i(32, 32))
	_place(atlas, water, Rect2i(192, 144, 16, 16), Vector2i(96, 32))
	_place(atlas, forest, Rect2i(16, 32, 16, 16), Vector2i(0, 32))
	_place(atlas, beach, Rect2i(192, 112, 16, 16), Vector2i(64, 32))
	_place(atlas, soil, Rect2i(160, 32, 16, 16), Vector2i(32, 32))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var error := atlas.save_png(ProjectSettings.globalize_path(OUT))
	if error != OK:
		push_error("Unable to save runtime atlas: %s" % error)
	_build_character_atlas()
	quit(error)

func _load(relative_path: String) -> Image:
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(ROOT + relative_path))
	if error != OK:
		push_error("Unable to load source atlas: %s" % relative_path)
		quit(error)
	return image

func _place(destination: Image, source: Image, region: Rect2i, position: Vector2i) -> void:
	for y in 2:
		for x in 2:
			destination.blit_rect(source, region, position + Vector2i(x * 16, y * 16))

func _build_character_atlas() -> void:
	var idle := _load("Character/Character/Pre-made/Alex/Idle.png")
	var walk := _load("Character/Character/Pre-made/Alex/Walk.png")
	var atlas := Image.create(192, 128, false, Image.FORMAT_RGBA8)
	for row in 3:
		var idle_frame := _frame(idle, row, 0)
		atlas.blit_rect(idle_frame, Rect2i(0, 0, 32, 32), Vector2i(0, row * 32))
		for column in 1:
			atlas.blit_rect(_frame(walk, row, column), Rect2i(0, 0, 32, 32), Vector2i(column * 32, row * 32))
		for column in 2:
			atlas.blit_rect(_frame(walk, row, column + 1), Rect2i(0, 0, 32, 32), Vector2i((column + 1) * 32, row * 32))
		atlas.blit_rect(_frame(walk, row, 0), Rect2i(0, 0, 32, 32), Vector2i(4 * 32, row * 32))
		atlas.blit_rect(_frame(walk, row, 1), Rect2i(0, 0, 32, 32), Vector2i(5 * 32, row * 32))
	var left_idle := _frame(idle, 1, 0)
	left_idle.flip_x()
	atlas.blit_rect(left_idle, Rect2i(0, 0, 32, 32), Vector2i(0, 3 * 32))
	for column in 6:
		var frame := _frame(walk, 1, mini(column, 5))
		frame.flip_x()
		atlas.blit_rect(frame, Rect2i(0, 0, 32, 32), Vector2i(column * 32, 3 * 32))
	var error := atlas.save_png(ProjectSettings.globalize_path(CHARACTER_OUT))
	if error != OK:
		push_error("Unable to save character atlas: %s" % error)

func _frame(source: Image, row: int, column: int) -> Image:
	var frame := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	frame.blit_rect(source, Rect2i(column * 32, row * 32, 32, 32), Vector2i.ZERO)
	return frame
