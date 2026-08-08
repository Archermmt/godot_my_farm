class_name FarmPlayer
extends CharacterBody2D

const COLUMNS := 6
const DIRECTION_ROWS := {
	&"down": 0,
	&"left": 1,
	&"right": 2,
	&"up": 3,
}
const STATE_COLUMNS := {
	&"idle": 0,
	&"walk": 2,
	&"run": 4,
}
const STATE_FPS := {
	&"idle": 2.0,
	&"walk": 6.0,
	&"run": 10.0,
}

@export_range(1.0, 500.0, 1.0) var run_speed: float = 96.0
@export_range(1.0, 500.0, 1.0) var walk_speed: float = 48.0

var input_direction: Vector2 = Vector2.ZERO
var facing: StringName = &"down"
var motion_state: StringName = &"idle"
var walking: bool = false
var animation_phase: int = 0

var _animation_elapsed: float = 0.0
var _lock_reasons: Dictionary[StringName, bool] = {}

@onready var sprite: Sprite2D = $Visual/Sprite
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	assert(walk_speed < run_speed, "walk_speed must be lower than run_speed")
	_apply_frame()


func _physics_process(_delta: float) -> void:
	input_direction = movement_vector()
	walking = wants_walk()
	facing = resolve_facing(input_direction, facing)
	velocity = velocity_for(input_direction, walking)
	move_and_slide()
	set_motion(resolve_motion_state(input_direction, walking), facing)


func _process(delta: float) -> void:
	var fps: float = float(STATE_FPS.get(motion_state, 2.0))
	_animation_elapsed += delta
	var frame_duration: float = 1.0 / fps
	if _animation_elapsed >= frame_duration:
		_animation_elapsed = fmod(_animation_elapsed, frame_duration)
		animation_phase = (animation_phase + 1) % 2
		_apply_frame()


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
	if value not in DIRECTION_ROWS:
		return
	set_motion(motion_state, value)


func set_motion(next_state: StringName, next_facing: StringName) -> void:
	if next_state not in STATE_COLUMNS:
		next_state = &"idle"
	if next_facing not in DIRECTION_ROWS:
		next_facing = facing
	if motion_state != next_state:
		motion_state = next_state
		animation_phase = 0
		_animation_elapsed = 0.0
	facing = next_facing
	_apply_frame()


func current_frame_index() -> int:
	var row: int = int(DIRECTION_ROWS.get(facing, 0))
	var column: int = int(STATE_COLUMNS.get(motion_state, 0)) + animation_phase
	return row * COLUMNS + column


func _apply_frame() -> void:
	if sprite != null:
		sprite.frame = current_frame_index()


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
