extends SceneTree

const FRAME_SIZE := Vector2i(24, 32)
const COLUMNS := 6
const ROWS := 4
const OUTPUT_PATH := "res://assets/art/characters/player_placeholder.png"

const OUTLINE := Color8(28, 35, 38)
const HAT := Color8(244, 184, 46)
const HAT_DARK := Color8(181, 112, 30)
const HAIR := Color8(83, 52, 42)
const SKIN := Color8(235, 174, 130)
const SHIRT := Color8(38, 126, 139)
const SHIRT_LIGHT := Color8(67, 166, 164)
const TROUSERS := Color8(35, 58, 92)
const BOOTS := Color8(91, 58, 42)


func _init() -> void:
	var image := Image.create_empty(
		FRAME_SIZE.x * COLUMNS,
		FRAME_SIZE.y * ROWS,
		false,
		Image.FORMAT_RGBA8
	)
	image.fill(Color(0, 0, 0, 0))
	for row: int in ROWS:
		for column: int in COLUMNS:
			_draw_frame(image, Vector2i(column * FRAME_SIZE.x, row * FRAME_SIZE.y), row, column)
	var error: Error = image.save_png(OUTPUT_PATH)
	if error != OK:
		push_error("[PlayerAssetGenerator] failed: %s" % error_string(error))
		quit(1)
		return
	print("[PlayerAssetGenerator] wrote %s | %dx%d" % [OUTPUT_PATH, image.get_width(), image.get_height()])
	quit(0)


func _draw_frame(image: Image, origin: Vector2i, direction: int, column: int) -> void:
	var state_index: int = floori(float(column) / 2.0)
	var phase: int = column % 2
	var bob: int = -1 if state_index == 2 and phase == 1 else 0
	var stride: int = 0
	if state_index == 1:
		stride = -1 if phase == 0 else 1
	elif state_index == 2:
		stride = -2 if phase == 0 else 2

	_rect(image, origin, Rect2i(6, 4 + bob, 12, 11), OUTLINE)
	_rect(image, origin, Rect2i(7, 5 + bob, 10, 9), SKIN)
	_rect(image, origin, Rect2i(5, 3 + bob, 14, 4), HAT_DARK)
	_rect(image, origin, Rect2i(7, 1 + bob, 10, 5), HAT)
	_rect(image, origin, Rect2i(4, 6 + bob, 16, 2), HAT)

	match direction:
		0:
			_rect(image, origin, Rect2i(7, 6 + bob, 10, 3), HAIR)
			_rect(image, origin, Rect2i(9, 10 + bob, 2, 2), OUTLINE)
			_rect(image, origin, Rect2i(14, 10 + bob, 2, 2), OUTLINE)
		1:
			_rect(image, origin, Rect2i(7, 6 + bob, 4, 7), HAIR)
			_rect(image, origin, Rect2i(8, 10 + bob, 2, 2), OUTLINE)
		2:
			_rect(image, origin, Rect2i(13, 6 + bob, 4, 7), HAIR)
			_rect(image, origin, Rect2i(14, 10 + bob, 2, 2), OUTLINE)
		3:
			_rect(image, origin, Rect2i(7, 6 + bob, 10, 8), HAIR)
			_rect(image, origin, Rect2i(9, 7 + bob, 6, 3), HAT_DARK)

	_rect(image, origin, Rect2i(5, 14 + bob, 14, 11), OUTLINE)
	_rect(image, origin, Rect2i(6, 15 + bob, 12, 9), SHIRT)
	if direction == 0:
		_rect(image, origin, Rect2i(8, 16 + bob, 8, 3), SHIRT_LIGHT)
	elif direction == 3:
		_rect(image, origin, Rect2i(8, 16 + bob, 8, 5), HAT_DARK)
	else:
		var highlight_x: int = 7 if direction == 1 else 15
		_rect(image, origin, Rect2i(highlight_x, 16 + bob, 2, 6), SHIRT_LIGHT)

	_rect(image, origin, Rect2i(3, 16 + bob, 3, 7), SKIN)
	_rect(image, origin, Rect2i(18, 16 + bob, 3, 7), SKIN)
	if state_index > 0:
		_rect(image, origin, Rect2i(3, 17 + bob + phase, 3, 5), SKIN)
		_rect(image, origin, Rect2i(18, 18 + bob - phase, 3, 5), SKIN)

	var left_leg_x: int = 7 + min(0, stride)
	var right_leg_x: int = 13 + max(0, stride)
	_rect(image, origin, Rect2i(left_leg_x, 24 + bob, 4, 5), TROUSERS)
	_rect(image, origin, Rect2i(right_leg_x, 24 + bob, 4, 5), TROUSERS)
	_rect(image, origin, Rect2i(left_leg_x - 1, 28 + bob, 5, 3), BOOTS)
	_rect(image, origin, Rect2i(right_leg_x, 28 + bob, 5, 3), BOOTS)


func _rect(image: Image, origin: Vector2i, local_rect: Rect2i, color: Color) -> void:
	image.fill_rect(Rect2i(origin + local_rect.position, local_rect.size), color)
