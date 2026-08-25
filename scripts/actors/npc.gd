class_name FarmNpc
extends CharacterBody2D

const DIRECTIONS := [&"down", &"left", &"right", &"up"]

var state: NpcState = null
var schedule: NpcSchedule = null
var map: BaseMap = null
var target_cell := Vector2i.ZERO
var target_position := Vector2.ZERO
var _warning_key: StringName = &""
var _animation_state: StringName = &""

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Visual/Sprite
@onready var accent: Polygon2D = $Visual/Accent


func bind(next_state: NpcState, next_map: BaseMap) -> Error:
	if next_state == null or next_map == null:
		return ERR_INVALID_PARAMETER
	var next_schedule := DataCatalog.get_npc_schedule(next_state.schedule_id)
	if next_schedule == null or next_state.npc_id != next_schedule.npc_id:
		return ERR_INVALID_DATA
	if next_state.map_id != next_map.map_id or not next_map.contains_cell(next_state.cell):
		return ERR_INVALID_DATA
	state = next_state
	schedule = next_schedule
	map = next_map
	global_position = map.cell_to_world_center(state.cell)
	sprite.modulate = schedule.body_color
	accent.color = schedule.accent_color
	navigation_agent.path_desired_distance = 2.0
	navigation_agent.target_desired_distance = 2.0
	return refresh_target()


func refresh_target() -> Error:
	if state == null or schedule == null or map == null:
		return ERR_UNCONFIGURED
	target_cell = state.target_cell
	var spawn_id := state.target_spawn_id
	if spawn_id != &"":
		target_cell = map.world_to_cell(map.spawn_position(spawn_id))
	if not map.contains_cell(target_cell):
		return ERR_INVALID_DATA
	target_position = map.cell_to_world_center(target_cell)
	navigation_agent.target_position = target_position
	if map.is_walkable(target_cell):
		_warning_key = &""
	else:
		_warn_unreachable(map.world_to_cell(global_position), target_cell)
	return OK


func _physics_process(_delta: float) -> void:
	if is_instance_valid(GameManager) and GameManager.is_paused():
		velocity = Vector2.ZERO
		_set_animation(false, state.facing if state != null else &"down")
		return
	if state == null or map == null or schedule == null:
		velocity = Vector2.ZERO
		_set_animation(false, state.facing if state != null else &"down")
		return
	if global_position.distance_to(target_position) <= 2.0:
		global_position = target_position
		state.cell = target_cell
		velocity = Vector2.ZERO
		_set_animation(false, state.facing)
		return
	# NavigationAgent2D owns path calculation. Maps without a baked navigation
	# region fall back to the current target so NPCs remain functional while
	# navigation data is authored.
	var next_position := target_position
	if not navigation_agent.is_navigation_finished():
		next_position = navigation_agent.get_next_path_position()
	var direction := global_position.direction_to(next_position)
	if direction.is_zero_approx():
		_set_animation(false, state.facing)
		return
	state.facing = _facing_for(direction, state.facing)
	velocity = direction * schedule.move_speed
	move_and_slide()
	if map.contains_cell(map.world_to_cell(global_position)):
		state.cell = map.world_to_cell(global_position)
	_set_animation(true, state.facing)


func _set_animation(moving: bool, facing: StringName) -> void:
	var next_state := ("walk_" if moving else "idle_") + String(facing)
	if _animation_state == next_state:
		return
	_animation_state = next_state
	if animation_player.has_animation(next_state):
		animation_player.play(next_state)


func interaction_prompt() -> String:
	return "Talk"


func interact(player: FarmPlayer) -> void:
	if state == null:
		EventBus.request_invalid_feedback.emit(&"unavailable")
		return
	match state.npc_id if state != null else &"":
		&"npc_fisher": InteractManager.begin(&"npc_fisher_default", self, player)
		&"npc_ranger": InteractManager.begin(&"npc_ranger_default", self, player)
		_: InteractManager.begin(&"npc_villager_default", self, player)


func on_effect_area_entered(effect_area: EffectArea) -> void:
	var player := effect_area.get_parent() as FarmPlayer
	if player != null and state == null:
		return
	if player != null:
		InteractManager.show_prompt(self, player)


func on_effect_area_exited(_effect_area: EffectArea) -> void:
	InteractManager.hide_prompt(self)


func _warn_unreachable(from_cell: Vector2i, to_cell: Vector2i) -> void:
	var next_warning := StringName("%s:%s:%s" % [state.npc_id, from_cell, to_cell])
	if _warning_key == next_warning:
		return
	_warning_key = next_warning
	push_warning("[FarmNpc] unreachable target | npc=%s map=%s from=%s to=%s" % [state.npc_id, map.map_id, from_cell, to_cell])


static func _facing_for(direction: Vector2, previous: StringName) -> StringName:
	if absf(direction.x) > absf(direction.y):
		return &"right" if direction.x > 0.0 else &"left"
	if not is_zero_approx(direction.y):
		return &"down" if direction.y > 0.0 else &"up"
	return previous
