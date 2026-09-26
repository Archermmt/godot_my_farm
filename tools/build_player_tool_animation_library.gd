extends SceneTree

const OUTPUT := "res://scenes/actors/player/player_animations.tres"
const ROOT := "res://assets/art/extern/farm_rpg_tiny/Character/Character/Pre-made/Alex/"

func _init() -> void:
	var base := load(OUTPUT) as AnimationLibrary
	if base == null:
		push_error("Base player animation library is missing: %s" % OUTPUT)
		quit(1)
		return
	var tools := AnimationLibrary.new()
	_add_tool(tools, &"axe", "Axe.png", 6)
	_add_tool(tools, &"hoe", "Hoe.png", 6)
	_add_tool(tools, &"pickaxe", "Pickaxe.png", 6)
	_add_tool(tools, &"sickle", "Sickle.png", 6)
	_add_tool(tools, &"watering_can", "Watering.png", 8)
	for old_name in base.get_animation_list():
		var old_text := String(old_name)
		if old_text.begins_with("tool_") or old_text.begins_with("hold_"):
			base.remove_animation(old_name)
	for animation_name in tools.get_animation_list():
		if base.has_animation(animation_name):
			base.remove_animation(animation_name)
		base.add_animation(animation_name, tools.get_animation(animation_name))
	var error := ResourceSaver.save(base, OUTPUT)
	if error != OK:
		push_error("Unable to save player tool animation library: %s" % error)
		quit(1)
		return
	print("Generated %s" % OUTPUT)
	quit(0)

func _add_tool(library: AnimationLibrary, tool_id: StringName, file_name: String, columns: int) -> void:
	var texture := load(ROOT + file_name) as Texture2D
	if texture == null:
		push_error("Missing tool animation texture: %s" % file_name)
		return
	for direction in 4:
		var direction_name: String = ["down", "left", "right", "up"][direction]
		var row := 0 if direction == 0 else 2 if direction == 1 or direction == 2 else 1
		var frames: Array[int] = []
		for frame in columns:
			frames.append(row * columns + frame)
		var animation := Animation.new()
		animation.length = float(columns) * 0.1
		animation.loop_mode = Animation.LOOP_NONE
		_add_value(animation, NodePath("Visual/Sprite:texture"), texture)
		_add_value(animation, NodePath("Visual/Sprite:hframes"), columns)
		_add_value(animation, NodePath("Visual/Sprite:vframes"), 3)
		_add_value(animation, NodePath("Visual/Sprite:flip_h"), direction == 1)
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, NodePath("Visual/Sprite:frame"))
		for index in frames.size():
			animation.track_insert_key(track, float(index) * 0.1, frames[index])
		library.add_animation(StringName("%s_use_%s" % [tool_id, direction_name]), animation)
		var hold := Animation.new()
		hold.length = 0.1
		hold.loop_mode = Animation.LOOP_LINEAR
		_add_value(hold, NodePath("Visual/Sprite:texture"), texture)
		_add_value(hold, NodePath("Visual/Sprite:hframes"), columns)
		_add_value(hold, NodePath("Visual/Sprite:vframes"), 3)
		_add_value(hold, NodePath("Visual/Sprite:flip_h"), direction == 1)
		_add_value(hold, NodePath("Visual/Sprite:frame"), row * columns)
		library.add_animation(StringName("%s_hold_%s" % [tool_id, direction_name]), hold)

func _add_value(animation: Animation, path: NodePath, value: Variant) -> void:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, path)
	animation.track_insert_key(track, 0.0, value)
