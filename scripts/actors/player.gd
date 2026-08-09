class_name FarmPlayer
extends CharacterBody2D

const DIRECTIONS := [&"down", &"left", &"right", &"up"]
const MOTION_STATES := [&"idle", &"walk", &"run"]

@export_range(1.0, 500.0, 1.0) var run_speed: float = 96.0
@export_range(1.0, 500.0, 1.0) var walk_speed: float = 48.0

var input_direction: Vector2 = Vector2.ZERO
var facing: StringName = &"down"
var motion_state: StringName = &"idle"
var walking: bool = false

var _lock_reasons: Dictionary[StringName, bool] = {}

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	assert(walk_speed < run_speed, "walk_speed must be lower than run_speed")
	_play_animation()


func _physics_process(_delta: float) -> void:
	input_direction = movement_vector()
	walking = wants_walk()
	facing = resolve_facing(input_direction, facing)
	velocity = velocity_for(input_direction, walking)
	move_and_slide()
	set_motion(resolve_motion_state(input_direction, walking), facing)

func movement_vector() -> Vector2:
	if is_input_locked():
		return Vector2.ZERO
	var raw := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return normalized_direction(raw)


func wants_walk() -> bool:
	return not is_input_locked() and Input.is_action_pressed("walk_modifier")


func velocity_for(direction: Vector2, is_walking: bool) -> Vector2:
	if direction.is_zero_approx():
		return Vector2.ZERO
	return normalized_direction(direction) * speed_for(is_walking)


func speed_for(is_walking: bool) -> float:
	return walk_speed if is_walking else run_speed


func set_facing(value: StringName) -> void:
	if value not in DIRECTIONS:
		return
	set_motion(motion_state, value)


func set_motion(next_state: StringName, next_facing: StringName) -> void:
	if next_state not in MOTION_STATES:
		next_state = &"idle"
	if next_facing not in DIRECTIONS:
		next_facing = facing
	motion_state = next_state
	facing = next_facing
	_play_animation()


func animation_name() -> StringName:
	return animation_name_for(motion_state, facing)


func _play_animation() -> void:
	if animation_player == null:
		return
	var next_animation: StringName = animation_name()
	if animation_player.current_animation != next_animation or not animation_player.is_playing():
		animation_player.play(next_animation)


func lock_input(reason: StringName) -> Error:
	if reason == &"":
		return ERR_INVALID_PARAMETER
	_lock_reasons[reason] = true
	return OK


func unlock_input(reason: StringName) -> Error:
	if reason == &"":
		return ERR_INVALID_PARAMETER
	if not _lock_reasons.erase(reason):
		return ERR_DOES_NOT_EXIST
	return OK


func is_input_locked() -> bool:
	return not _lock_reasons.is_empty()


func input_lock_reasons() -> Array[StringName]:
	var reasons: Array[StringName] = []
	reasons.assign(_lock_reasons.keys())
	return reasons


func clear_input_locks() -> void:
	_lock_reasons.clear()


func set_camera_limits(world_rect: Rect2i) -> Error:
	if world_rect.size.x <= 0 or world_rect.size.y <= 0:
		return ERR_INVALID_PARAMETER
	camera.limit_left = world_rect.position.x
	camera.limit_top = world_rect.position.y
	camera.limit_right = world_rect.end.x
	camera.limit_bottom = world_rect.end.y
	return OK


func debug_snapshot() -> Dictionary:
	return {
		"position": global_position,
		"velocity": velocity,
		"input_direction": input_direction,
		"facing": facing,
		"motion_state": motion_state,
		"walking": walking,
		"input_locked": is_input_locked(),
		"animation": animation_name(),
		"animation_player_playing": animation_player.is_playing(),
		"camera_enabled": camera.enabled,
	}


static func normalized_direction(raw: Vector2) -> Vector2:
	if raw.is_zero_approx():
		return Vector2.ZERO
	return raw.normalized()


static func resolve_facing(direction: Vector2, previous: StringName = &"down") -> StringName:
	if not is_zero_approx(direction.x):
		return &"right" if direction.x > 0.0 else &"left"
	if not is_zero_approx(direction.y):
		return &"down" if direction.y > 0.0 else &"up"
	return previous


static func resolve_motion_state(direction: Vector2, is_walking: bool) -> StringName:
	if direction.is_zero_approx():
		return &"idle"
	return &"walk" if is_walking else &"run"


static func animation_name_for(state: StringName, direction: StringName) -> StringName:
	var safe_state: StringName = state if state in MOTION_STATES else &"idle"
	var safe_direction: StringName = direction if direction in DIRECTIONS else &"down"
	return StringName("%s_%s" % [safe_state, safe_direction])
