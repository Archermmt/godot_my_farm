class_name FarmNpc
extends Interactable

const DIRECTIONS := [&"down", &"left", &"right", &"up"]
const PORTAL_GRAPH: Dictionary[StringName, Array] = {
	&"farm": [&"field", &"beach"],
	&"field": [&"farm"],
	&"beach": [&"farm"],
}
const PORTAL_ARRIVAL_CELLS: Dictionary[String, Vector2i] = {
	"farm>field": Vector2i(2, 19),
	"field>farm": Vector2i(44, 8),
	"farm>beach": Vector2i(29, 2),
	"beach>farm": Vector2i(24, 31),
}
const NAVIGATION_MARGIN := 8.0

var state: NpcState = null
var schedule: NpcSchedule = null
var schedules: Array[NpcSchedule] = []
var map: BaseMap = null
var _wander_rng := RandomNumberGenerator.new()
var _wandering := false
var _wander_move_logged := false
var _target_blocked_logged := false
var _warning_key: StringName = &""
var _animation_state: StringName = &""
var facing: StringName = &"down"
var _last_motion_position := Vector2.ZERO
var _stuck_time := 0.0
const STUCK_TIMEOUT := 1.5

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Visual/Sprite
@onready var accent: Polygon2D = $Visual/Accent
@onready var wander_timer: Timer = $WanderTimer
var velocity := Vector2.ZERO


func _ready() -> void:
	super._ready()
	_wander_rng.randomize()
	navigation_agent.radius = NAVIGATION_MARGIN
	navigation_agent.path_desired_distance = 2.0
	navigation_agent.target_desired_distance = NAVIGATION_MARGIN
	if not navigation_agent.velocity_computed.is_connected(_on_navigation_velocity_computed):
		navigation_agent.velocity_computed.connect(_on_navigation_velocity_computed)
	if not wander_timer.timeout.is_connected(_on_wander_timer_timeout):
		wander_timer.timeout.connect(_on_wander_timer_timeout)
	if not EventBus.advanced_hour.is_connected(_on_advanced_hour):
		EventBus.advanced_hour.connect(_on_advanced_hour)
	if not EventBus.day_advanced.is_connected(_on_day_advanced):
		EventBus.day_advanced.connect(_on_day_advanced)


func _exit_tree() -> void:
	if EventBus.advanced_hour.is_connected(_on_advanced_hour):
		EventBus.advanced_hour.disconnect(_on_advanced_hour)
	if EventBus.day_advanced.is_connected(_on_day_advanced):
		EventBus.day_advanced.disconnect(_on_day_advanced)


func _refresh_schedule() -> Error:
	if state == null or schedule == null or map == null:
		return ERR_UNCONFIGURED
	var active_schedule := _active_schedule()
	var next_map: StringName = active_schedule.map_id if active_schedule != null else schedule.map_id
	var next_position: Vector2 = (
		active_schedule.target_position if active_schedule != null else schedule.target_position
	)
	var next_behavior_id: StringName = active_schedule.behavior_id if active_schedule != null else schedule.behavior_id
	var event_id: StringName = active_schedule.id if active_schedule != null else &"fallback"
	if active_schedule != null:
		schedule = active_schedule
	var previous_map := state.map_id
	state.behavior_id = next_behavior_id
	if previous_map == next_map:
		_set_navigation_target(next_position)
	else:
		state.target_position = next_position
		navigation_agent.target_position = next_position
	GameManager.debug(
		"[FarmNpc] schedule target | npc=%s schedule=%s map=%s target=%s zone=%s interval=%.2f"
		% [state.npc_id, event_id, next_map, state.target_position, schedule.wander_zone, schedule.wander_interval]
	)
	_wandering = false
	if wander_timer != null:
		wander_timer.stop()
	if wander_timer != null:
		wander_timer.stop()
	_wander_move_logged = false
	_target_blocked_logged = false
	_stuck_time = 0.0
	_last_motion_position = global_position
	if previous_map != next_map:
		var arrival_cell = _portal_arrival_cell(previous_map, next_map)
		if arrival_cell == null:
			return ERR_INVALID_DATA
		state.map_id = next_map
		state.current_position = map.cell_to_world(arrival_cell)
		state.current_event_id = event_id
		visible = false
		set_physics_process(false)
		EventBus.npc_change_map.emit(state.npc_id, previous_map, next_map)
		return OK
	state.current_event_id = event_id
	visible = true
	set_physics_process(true)
	if state.target_position == Vector2.ZERO:
		return ERR_INVALID_DATA
	var target_cell := map.world_to_cell(state.target_position)
	if map.check_cell(target_cell, CellState.CellCondition.WALKABLE):
		_warning_key = &""
	return OK


func _active_schedule() -> NpcSchedule:
	var calendar := CalendarManager.calendar
	if calendar == null:
		return null
	var minute := calendar.minute_of_day()
	var matches: Array[NpcSchedule] = []
	for candidate: NpcSchedule in schedules:
		if candidate == null:
			continue
		if candidate.start_minute <= minute and candidate.matches_date(calendar.season(), calendar.month, calendar.weekday):
			matches.append(candidate)
		else:
			var previous_month := 12 if calendar.month == 1 else calendar.month - 1
			var previous_weekday := 7 if calendar.weekday == 1 else calendar.weekday - 1
			if candidate.start_minute > minute and candidate.matches_date(calendar.season(previous_month), previous_month, previous_weekday):
				matches.append(candidate)
	if matches.is_empty():
		return null
	matches.sort_custom(
		func(left: NpcSchedule, right: NpcSchedule) -> bool:
			if left.priority != right.priority:
				return left.priority > right.priority
			if left.start_minute != right.start_minute:
				return left.start_minute > right.start_minute
			return String(left.id) < String(right.id)
	)
	return matches[0]


func _portal_arrival_cell(from_map: StringName, to_map: StringName) -> Variant:
	if from_map == &"" or to_map == &"" or from_map == to_map:
		return null
	var queue: Array[StringName] = [from_map]
	var previous: Dictionary[StringName, StringName] = {from_map: &""}
	while not queue.is_empty():
		var current: StringName = queue.pop_front()
		for neighbor: StringName in PORTAL_GRAPH.get(current, []):
			if previous.has(neighbor):
				continue
			previous[neighbor] = current
			if neighbor == to_map:
				var route: Array[StringName] = [to_map]
				var cursor: StringName = current
				while cursor != &"":
					route.push_front(cursor)
					cursor = previous.get(cursor, &"")
				return PORTAL_ARRIVAL_CELLS.get("%s>%s" % [route[route.size() - 2], to_map], null)
			queue.append(neighbor)
	return null


func _physics_process(_delta: float) -> void:
	if is_instance_valid(GameManager) and CalendarManager.is_paused():
		velocity = Vector2.ZERO
		navigation_agent.velocity = Vector2.ZERO
		_set_animation(false)
		return
	if state == null or map == null or schedule == null:
		velocity = Vector2.ZERO
		navigation_agent.velocity = Vector2.ZERO
		_set_animation(false)
		return
	if global_position.distance_to(_last_motion_position) < 0.5 and global_position.distance_to(state.target_position) > navigation_agent.target_desired_distance:
		_stuck_time += _delta
	else:
		_stuck_time = 0.0
		_last_motion_position = global_position
	if _stuck_time >= STUCK_TIMEOUT:
		velocity = Vector2.ZERO
		navigation_agent.velocity = Vector2.ZERO
		_set_animation(false)
		return
	if global_position.distance_to(state.target_position) <= navigation_agent.target_desired_distance:
		if not _target_blocked_logged:
			GameManager.debug(
				"[FarmNpc] target reached | npc=%s schedule=%s position=%s wander=%s"
				% [state.npc_id, schedule.id, global_position, _wandering]
			)
			_target_blocked_logged = true
		state.current_position = global_position
		velocity = Vector2.ZERO
		navigation_agent.velocity = Vector2.ZERO
		facing = &"down"
		_set_animation(false)
		if schedule.wander_zone.x > 0.0 and schedule.wander_zone.y > 0.0:
			if not _wandering and wander_timer != null:
				_wandering = true
				var wait_time := _wander_rng.randf_range(0.0, maxf(schedule.wander_interval, 0.0))
				wander_timer.start(wait_time)
				GameManager.debug("[FarmNpc] wander wait | npc=%s schedule=%s wait=%.2f" % [state.npc_id, schedule.id, wait_time])
				return
		return
	if not navigation_agent.is_target_reachable():
		if _project_target_to_navigation():
			_target_blocked_logged = false
			return
		if not _target_blocked_logged:
			_warn_unreachable(map.world_to_cell(global_position), map.world_to_cell(state.target_position))
			_target_blocked_logged = true
		navigation_agent.velocity = Vector2.ZERO
		velocity = Vector2.ZERO
		_set_animation(false)
		return
	var next_position := navigation_agent.get_next_path_position()
	if navigation_agent.is_navigation_finished():
		next_position = state.target_position
	var direction := global_position.direction_to(next_position)
	if direction.is_zero_approx():
		if not _target_blocked_logged:
			GameManager.debug(
				"[FarmNpc] navigation idle | npc=%s schedule=%s position=%s target=%s agent_finished=%s"
				% [state.npc_id, schedule.id, global_position, state.target_position, navigation_agent.is_navigation_finished()]
			)
			_target_blocked_logged = true
			navigation_agent.velocity = Vector2.ZERO
			_set_animation(false)
			return
	facing = _facing_for(direction, facing)
	velocity = direction * schedule.move_speed
	navigation_agent.velocity = velocity
	if _wandering and not _wander_move_logged:
		GameManager.debug("[FarmNpc] wander move | npc=%s position=%s target=%s" % [state.npc_id, global_position, state.target_position])
		_wander_move_logged = true
	if map.has_static_cell(map.world_to_cell(global_position)):
		state.current_position = global_position
	_set_animation(true)


func _on_navigation_velocity_computed(safe_velocity: Vector2) -> void:
	if state == null or map == null or schedule == null or CalendarManager.is_paused():
		return
	velocity = safe_velocity
	if safe_velocity.is_zero_approx():
		_set_animation(false)
		return
	global_position += safe_velocity * get_physics_process_delta_time()
	if map.has_static_cell(map.world_to_cell(global_position)):
		state.current_position = global_position
	_set_animation(true)

func _on_wander_timer_timeout() -> void:
	if state == null or schedule == null or not _wandering:
		return
	var zone := schedule.wander_zone * 0.5
	state.target_position = schedule.target_position + Vector2(
		_wander_rng.randf_range(-zone.x, zone.x), _wander_rng.randf_range(-zone.y, zone.y)
	)
	_set_navigation_target(state.target_position)
	_wander_move_logged = false
	GameManager.debug("[FarmNpc] wander next | npc=%s schedule=%s target=%s" % [state.npc_id, schedule.id, state.target_position])


func _set_navigation_target(requested_position: Vector2) -> void:
	var target_position := requested_position
	var navigation_map := navigation_agent.get_navigation_map()
	if navigation_map.is_valid():
		var closest_point := NavigationServer2D.map_get_closest_point(navigation_map, requested_position)
		if closest_point != Vector2.ZERO or requested_position == Vector2.ZERO:
			target_position = closest_point
			if target_position.distance_to(requested_position) > 0.01:
				GameManager.debug(
					"[FarmNpc] target projected | npc=%s requested=%s projected=%s"
					% [state.npc_id if state != null else &"", requested_position, target_position]
				)
	state.target_position = target_position
	navigation_agent.target_position = target_position


func _project_target_to_navigation() -> bool:
	var navigation_map := navigation_agent.get_navigation_map()
	if not navigation_map.is_valid():
		return false
	var requested := state.target_position
	var projected := NavigationServer2D.map_get_closest_point(navigation_map, requested)
	if projected == Vector2.ZERO and requested != Vector2.ZERO:
		return false
	var current_point := NavigationServer2D.map_get_closest_point(navigation_map, global_position)
	var path := NavigationServer2D.map_get_path(navigation_map, current_point, projected, true)
	if path.size() < 2:
		var best_distance := INF
		var best_point := Vector2.ZERO
		for radius: float in [16.0, 32.0, 48.0, 64.0, 96.0, 128.0, 160.0]:
			for direction: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
				var candidate := NavigationServer2D.map_get_closest_point(
					navigation_map, requested + direction * radius
				)
				if candidate == Vector2.ZERO:
					continue
				var candidate_path := NavigationServer2D.map_get_path(navigation_map, current_point, candidate, true)
				if candidate_path.size() < 2:
					continue
				var candidate_distance := candidate.distance_to(requested)
				if candidate_distance < best_distance:
					best_distance = candidate_distance
					best_point = candidate
			if best_point != Vector2.ZERO:
				break
		if best_point == Vector2.ZERO:
			return false
		projected = best_point
	if projected.distance_to(requested) <= 0.01:
		return false
	state.target_position = projected
	navigation_agent.target_position = projected
	GameManager.debug(
		"[FarmNpc] target projected | npc=%s requested=%s projected=%s"
		% [state.npc_id, requested, projected]
	)
	return true


func _set_animation(moving: bool) -> void:
	var next_state := ("walk_" if moving else "idle_") + String(facing)
	if _animation_state == next_state:
		return
	_animation_state = next_state
	if animation_player.has_animation(next_state):
		animation_player.play(next_state)


func interaction_name() -> String:
	if state != null and state.npc_id != &"":
		return String(state.npc_id).replace("npc_", "").capitalize()
	return String(name).capitalize()


func interact() -> void:
	if state == null:
		EventBus.request_invalid_feedback.emit(&"unavailable")
		return
	var timeline_id: StringName = &"npc_villager_default"
	match state.npc_id:
		&"npc_fisher":
			timeline_id = &"npc_fisher_default"
		&"npc_ranger":
			timeline_id = &"npc_ranger_default"
	begin_dialogue(timeline_id)


func _warn_unreachable(from_cell: Vector2i, to_cell: Vector2i) -> void:
	var next_warning := StringName("%s:%s:%s" % [state.npc_id, from_cell, to_cell])
	if _warning_key == next_warning:
		return
	_warning_key = next_warning
	GameManager.debug(
		"[FarmNpc] unreachable target | npc=%s map=%s from=%s to=%s" % [state.npc_id, map.map_id, from_cell, to_cell]
	)


static func _facing_for(direction: Vector2, previous: StringName) -> StringName:
	if absf(direction.x) > absf(direction.y):
		return &"right" if direction.x > 0.0 else &"left"
	if not is_zero_approx(direction.y):
		return &"down" if direction.y > 0.0 else &"up"
	return previous


func to_state() -> NpcState:
	return state


func from_state(next_state: NpcState, next_map: BaseMap) -> Error:
	if next_state == null or next_map == null:
		return ERR_INVALID_PARAMETER
	var available_schedules := DataCatalog.get_npc_schedules(next_state.npc_id)
	if available_schedules.is_empty():
		return ERR_INVALID_DATA
	var next_schedule := DataCatalog.config.npc_schedules.get(next_state.schedule_id) as NpcSchedule
	if next_schedule == null:
		# Older saves stored the former parent schedule id (for example "villager").
		# The expanded schedule list has no parent resource, so use the first
		# deterministic definition as the compatibility fallback.
		next_schedule = available_schedules[0]
	if next_state.map_id != next_map.map_id:
		return ERR_INVALID_DATA
	state = next_state
	schedule = next_schedule
	schedules = available_schedules
	state.schedule_id = next_schedule.id
	map = next_map
	global_position = state.current_position
	facing = &"down"
	set_physics_process(true)
	visible = true
	return _refresh_schedule()


func _on_advanced_hour() -> void:
	_refresh_schedule()


func _on_day_advanced() -> void:
	# CalendarManager sets 06:00 directly during day rollover, so no hour signal
	# is emitted for that assignment. Reset from the new day's schedule signal.
	if state == null or map == null:
		return
	var active_schedule := _active_schedule()
	if active_schedule == null:
		return
	if active_schedule.map_id == state.map_id:
		global_position = active_schedule.target_position
		state.current_position = active_schedule.target_position
		state.target_position = active_schedule.target_position
	_refresh_schedule()
