extends SceneTree

const ROOT := "res://assets/art/extern/farm_rpg_tiny/Character/Character/Pre-made/"
const OUTPUT_ROOT := "res://scenes/actors/npcs/"

func _init() -> void:
	_build_npc("fisher", "Manu")
	_build_npc("ranger", "Tori")
	_build_npc("villager", "Lyria")
	quit(0)

func _build_npc(npc_id: String, character: String) -> void:
	var library := AnimationLibrary.new()
	var idle := load(ROOT + character + "/Idle.png") as Texture2D
	var walk := load(ROOT + character + "/Walk.png") as Texture2D
	var run := load(ROOT + character + "/Run.png") as Texture2D
	if idle == null or walk == null or run == null:
		push_error("Missing NPC textures for %s" % character)
		return
	for direction in 4:
		var name: String = ["down", "left", "right", "up"][direction]
		var row := 0 if direction == 0 else 1 if direction == 1 or direction == 2 else 2
		library.add_animation(StringName("idle_%s" % name), _make(idle, 4, row * 4, [row * 4], direction == 1, 0.5, true))
		var walk_frames: Array[int] = []
		for frame in 6:
			walk_frames.append(row * 6 + frame)
		library.add_animation(StringName("walk_%s" % name), _make(walk, 6, 0, walk_frames, direction == 1, 0.6, true))
		var run_row := 0 if direction == 0 else 2 if direction == 1 or direction == 2 else 1
		var run_frames: Array[int] = []
		for frame in 8:
			run_frames.append(run_row * 8 + frame)
		library.add_animation(StringName("run_%s" % name), _make(run, 8, 0, run_frames, direction == 1, 0.8, true))
	for tool in [["axe", "Axe.png", 6], ["hoe", "Hoe.png", 6], ["pickaxe", "Pickaxe.png", 6], ["sickle", "Sickle.png", 6], ["watering_can", "Watering.png", 8]]:
		var tool_file: String = "watering.png" if character == "Lyria" and tool[0] == "watering_can" else tool[1]
		var tool_texture := load(ROOT + character + "/" + tool_file) as Texture2D
		var columns: int = tool[2]
		if tool_texture == null:
			continue
		for direction in 4:
			var direction_name: String = ["down", "left", "right", "up"][direction]
			var row := 0 if direction == 0 else 2 if direction == 1 or direction == 2 else 1
			var frames: Array[int] = []
			for frame in columns:
				frames.append(row * columns + frame)
			library.add_animation(StringName("%s_use_%s" % [tool[0], direction_name]), _make(tool_texture, columns, 0, frames, direction == 1, float(columns) * 0.1, false))
	var output := OUTPUT_ROOT + "%s_animation.tres" % npc_id
	var error := ResourceSaver.save(library, output)
	if error != OK:
		push_error("Unable to save %s: %s" % [output, error])

func _make(texture: Texture2D, columns: int, _unused_row: int, frames: Array[int], mirrored: bool, length: float, looped: bool) -> Animation:
	var animation := Animation.new()
	animation.length = length
	animation.loop_mode = Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE
	_add(animation, NodePath("Visual/Sprite:texture"), texture)
	_add(animation, NodePath("Visual/Sprite:hframes"), columns)
	_add(animation, NodePath("Visual/Sprite:vframes"), 3)
	_add(animation, NodePath("Visual/Sprite:flip_h"), mirrored)
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath("Visual/Sprite:frame"))
	animation.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
	var step := length / float(frames.size())
	for index in frames.size():
		animation.track_insert_key(track, step * index, frames[index])
	return animation

func _add(animation: Animation, path: NodePath, value: Variant) -> void:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, path)
	animation.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
	animation.track_insert_key(track, 0.0, value)
