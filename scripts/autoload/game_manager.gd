class_name GameManagerService
extends Node

const DEFAULT_CONFIG_PATH := "res://data/game_config.tres"
const SAVE_SCHEMA_VERSION := 1
const SAVE_DIRECTORY := "user://saves"
const SAVE_FILE_TEMPLATE := SAVE_DIRECTORY + "/slot_%d.json"

var config: GameConfig = load(DEFAULT_CONFIG_PATH) as GameConfig

var player: PlayerState = null
var maps: Dictionary[StringName, MapState] = {}
var npcs: Dictionary[StringName, NpcState] = {}
var world_seed: int = 0
var current_slot: int = -1
var game_version: String = "0.1.0"
var calendar: CalendarState = CalendarState.new()
var time_scale: float = 0.0
var _running: bool = false
var _pause_reasons: Dictionary[StringName, bool] = {}
var _time_accumulator: float = 0.0
var _ending_day: bool = false
var _save_in_progress := false
var save_directory: String = SAVE_DIRECTORY

var _initialized: bool = false

const NPC_PORTAL_GRAPH: Dictionary[StringName, Array] = {
	&"farm": [&"field", &"beach"],
	&"field": [&"farm"],
	&"beach": [&"farm"],
}
const NPC_PORTAL_ARRIVAL_CELLS: Dictionary[String, Vector2i] = {
	"farm>field": Vector2i(2, 19),
	"field>farm": Vector2i(44, 8),
	"farm>beach": Vector2i(29, 2),
	"beach>farm": Vector2i(24, 31),
}


func _init() -> void:
	time_scale = config.initial_time_scale


func _ready() -> void:
	var time_error := configure_time_scale(config.initial_time_scale)
	if time_error != OK:
		push_error("[GameManager] invalid initial time scale: %s" % config.initial_time_scale)
		return
	if DataCatalog.is_ready_for_game():
		var error: Error = new_game(config.default_world_seed)
		if error != OK:
			push_error("[GameManager] failed to create default new game: %s" % error_string(error))


func _process(delta: float) -> void:
	if is_instance_valid(CalendarManager):
		return
	if not can_advance() or delta <= 0.0:
		return
	_time_accumulator += delta * time_scale
	var whole_minutes := floori(_time_accumulator)
	if whole_minutes <= 0:
		return
	_time_accumulator -= whole_minutes
	advance_minutes(whole_minutes)


func configure_time_scale(value: float) -> Error:
	if self == GameManager and is_instance_valid(CalendarManager) and CalendarManager.is_configured():
		return CalendarManager.configure_time_scale(value)
	if value <= 0.0 or is_nan(value) or is_inf(value):
		return ERR_INVALID_PARAMETER
	time_scale = value
	_time_accumulator = 0.0
	return OK


func new_game(p_seed: int) -> Error:
	if not DataCatalog.is_ready_for_game():
		return ERR_UNCONFIGURED

	var next_player := PlayerState.new()
	var player_error := next_player.initialize(config.player_state_template)
	if player_error != OK:
		return player_error
	if not _validate_player_containers(next_player):
		return ERR_INVALID_DATA

	var next_maps: Dictionary[StringName, MapState] = {}
	for map_id: StringName in [&"farm", &"field", &"beach"]:
		var map_state := MapState.new()
		map_state.map_id = map_id
		next_maps[map_id] = map_state

	player = next_player
	maps = next_maps
	npcs = {}
	world_seed = p_seed
	current_slot = -1
	calendar = CalendarState.new()
	sync_calendar_season()
	_initialize_npcs()
	_running = false
	_pause_reasons.clear()
	_time_accumulator = 0.0
	_ending_day = false
	_initialized = true
	EventBus.player_state_changed.emit(player)
	print("[GameManager] new game | seed=%d map=%s inventory=%d/%d" % [
		world_seed,
		player.map_id,
		player.used_slot_count(),
		player.backpack_state.capacity(&"inventory") + player.backpack_state.capacity(&"toolbar") + player.backpack_state.capacity(&"itembar"),
	])
	return OK


func is_initialized() -> bool:
	return _initialized


func reset() -> void:
	player = null
	maps.clear()
	npcs.clear()
	world_seed = 0
	current_slot = -1
	calendar = CalendarState.new()
	sync_calendar_season()
	_running = false
	_pause_reasons.clear()
	_time_accumulator = 0.0
	_ending_day = false
	_initialized = false


func start() -> void:
	_running = true


func stop() -> void:
	_running = false


func is_running() -> bool:
	return _running


func pause(reason: StringName) -> Error:
	if reason == &"":
		return ERR_INVALID_PARAMETER
	_pause_reasons[reason] = true
	return OK


func resume(reason: StringName) -> Error:
	if reason == &"":
		return ERR_INVALID_PARAMETER
	if not _pause_reasons.erase(reason):
		return ERR_DOES_NOT_EXIST
	return OK


func is_paused() -> bool:
	return not _pause_reasons.is_empty()


func can_advance() -> bool:
	return _running and not is_paused()


func skip_day() -> Error:
	return request_end_day()


func advance_minutes(minutes: int) -> Error:
	if self == GameManager and is_instance_valid(CalendarManager) and CalendarManager.is_configured():
		return CalendarManager.advance_minutes(minutes)
	if not _initialized or minutes < 0:
		return ERR_INVALID_PARAMETER if minutes < 0 else ERR_UNCONFIGURED
	if minutes == 0:
		return OK
	for _index in range(minutes):
		var before := calendar.to_dict()
		calendar.add_minutes(1)
		sync_calendar_season()
		EventBus.time_advanced.emit(1, before, 1)
		if calendar.hour >= 23:
			_refresh_npc_schedules()
			return request_end_day()
	_refresh_npc_schedules()
	return OK


func request_end_day() -> Error:
	if not _initialized:
		return ERR_UNCONFIGURED
	if _ending_day:
		return OK
	_ending_day = true
	if self == GameManager and is_instance_valid(MapManager) and MapManager.can_run_day_transition():
		var transition_error := MapManager.request_day_transition()
		if transition_error == OK:
			return OK
		_ending_day = false
		return transition_error
	_complete_day()
	return OK


func complete_day() -> Error:
	if not _initialized:
		return ERR_UNCONFIGURED
	if not _ending_day:
		return ERR_UNAVAILABLE
	_complete_day()
	return OK


func cancel_end_day() -> void:
	_ending_day = false


func is_ending_day() -> bool:
	return _ending_day


func _complete_day() -> void:
	var previous_day := calendar.day
	if self == GameManager and is_instance_valid(CalendarManager) and CalendarManager.is_configured():
		previous_day = CalendarManager.advance_to_next_day()
	else:
		calendar.add_minutes((24 * 60) - calendar.minute_of_day())
		calendar.hour = 6
		calendar.minute = 0
		sync_calendar_season()
	_refresh_npc_schedules()
	EventBus.day_advanced.emit(previous_day, calendar.day)
	if player != null:
		player.restore_for_new_day()
		player.map_id = &"farm"
		player.spawn_id = &"wake"
		EventBus.player_state_changed.emit(player)
	_ending_day = false


func pause_reasons() -> Array[StringName]:
	var reasons: Array[StringName] = []
	reasons.assign(_pause_reasons.keys())
	reasons.sort()
	return reasons


func snapshot() -> Dictionary:
	if not _initialized:
		return {}
	var map_data: Array[Dictionary] = []
	var map_ids: Array[StringName] = []
	map_ids.assign(maps.keys())
	map_ids.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	for map_id: StringName in map_ids:
		map_data.append(maps[map_id].to_dict())
	var npc_data: Array[Dictionary] = []
	var npc_ids: Array[StringName] = []
	npc_ids.assign(npcs.keys())
	npc_ids.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	for npc_id: StringName in npc_ids:
		npc_data.append(npcs[npc_id].to_dict())
	return {
		"game_version": game_version,
		"world_seed": world_seed,
		"current_slot": current_slot,
		"player": player.to_dict(),
		"maps": map_data,
		"npcs": npc_data,
	}.duplicate(true)


func time_snapshot() -> Dictionary:
	return {
		"calendar": calendar.to_dict(),
		"time_scale": time_scale,
		"running": _running,
		"pause_reasons": SerializationUtil.string_name_array_to_strings(pause_reasons()),
	}.duplicate(true)


func can_snapshot() -> bool:
	return _initialized


func build_snapshot() -> Dictionary:
	if not can_snapshot():
		return {}
	return {
		"game": snapshot(),
		"time": time_snapshot(),
	}.duplicate(true)


func save_path(slot: int = 0) -> String:
	return "%s/slot_%d.json" % [save_directory, maxi(0, slot)]


func save_exists(slot: int = 0) -> bool:
	return FileAccess.file_exists(save_path(slot))


func replace_build_snapshot(data: Dictionary) -> Error:
	if not SerializationUtil.has_valid_dictionary(data, "game") or not SerializationUtil.has_valid_dictionary(data, "time"):
		return ERR_INVALID_DATA
	var time_data := data.get("time", {}) as Dictionary
	var next_calendar := CalendarState.from_dict(time_data.get("calendar", {}) as Dictionary)
	var raw_time_scale: Variant = time_data.get("time_scale", config.initial_time_scale)
	if next_calendar == null or (typeof(raw_time_scale) != TYPE_FLOAT and typeof(raw_time_scale) != TYPE_INT) or float(raw_time_scale) <= 0.0 or not SerializationUtil.has_valid_bool(time_data, "running") or not SerializationUtil.has_valid_array(time_data, "pause_reasons"):
		return ERR_INVALID_DATA
	var next_pause_reasons: Dictionary[StringName, bool] = {}
	for raw_reason: Variant in time_data.get("pause_reasons", []) as Array:
		if typeof(raw_reason) != TYPE_STRING or String(raw_reason).is_empty():
			return ERR_INVALID_DATA
		next_pause_reasons[StringName(str(raw_reason))] = true
	var game_error := replace_snapshot(data.get("game", {}) as Dictionary)
	if game_error != OK:
		return game_error
	calendar = next_calendar
	sync_calendar_season()
	if self == GameManager and is_instance_valid(CalendarManager):
		CalendarManager.refresh()
	_refresh_npc_schedules()
	time_scale = float(time_data.get("time_scale", config.initial_time_scale))
	_running = bool(time_data.get("running", false))
	_pause_reasons = next_pause_reasons
	_time_accumulator = 0.0
	_ending_day = false
	return OK


func save_slot(slot: int = 0) -> Error:
	if not can_snapshot() or _save_in_progress or slot < 0:
		return ERR_BUSY if _save_in_progress else ERR_UNAVAILABLE
	if self == GameManager and is_instance_valid(MapManager) and MapManager.is_transitioning():
		return ERR_BUSY
	_save_in_progress = true
	var previous_slot := current_slot
	current_slot = slot
	var result := _write_save_file(slot)
	_save_in_progress = false
	if result == OK:
		EventBus.save_completed.emit(slot)
	else:
		current_slot = previous_slot
		_notify_save_error("SAVE FAILED")
	return result


func load_slot(slot: int = 0) -> Error:
	if not _initialized:
		return ERR_UNAVAILABLE
	if _save_in_progress or slot < 0:
		return ERR_BUSY if _save_in_progress else ERR_INVALID_PARAMETER
	if not FileAccess.file_exists(save_path(slot)):
		_notify_save_error("NO SAVE FOUND")
		return ERR_FILE_NOT_FOUND
	if self == GameManager and is_instance_valid(MapManager) and (MapManager.is_transitioning() or _dialogue_is_active()):
		return ERR_BUSY
	var file := FileAccess.open(save_path(slot), FileAccess.READ)
	if file == null:
		return ERR_CANT_OPEN
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_notify_save_error("SAVE DATA CORRUPTED")
		return ERR_INVALID_DATA
	var envelope := parsed as Dictionary
	var migrated := _migrate_save(envelope)
	if migrated.is_empty():
		_notify_save_error("UNSUPPORTED SAVE VERSION")
		return ERR_INVALID_DATA
	var before := build_snapshot()
	var result := replace_build_snapshot(migrated.get("snapshot", {}) as Dictionary)
	if result != OK:
		if not before.is_empty():
			replace_build_snapshot(before)
		_notify_save_error("SAVE DATA INVALID")
		return result
	if self == GameManager and is_instance_valid(MapManager) and MapManager.current_map() != null:
		var map_error := MapManager.apply_loaded_state()
		if map_error != OK:
			if not before.is_empty():
				replace_build_snapshot(before)
			_notify_save_error("MAP RESTORE FAILED")
			return map_error
	current_slot = slot
	EventBus.load_completed.emit(slot)
	return OK


func _write_save_file(slot: int) -> Error:
	var snapshot_data := build_snapshot()
	if snapshot_data.is_empty():
		return ERR_UNAVAILABLE
	var envelope := {
		"schema_version": SAVE_SCHEMA_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"game_version": game_version,
		"snapshot": snapshot_data,
	}.duplicate(true)
	var save_directory_path := ProjectSettings.globalize_path(save_directory)
	var directory_error := DirAccess.make_dir_recursive_absolute(save_directory_path)
	if directory_error != OK and not DirAccess.dir_exists_absolute(save_directory_path):
		return ERR_CANT_CREATE
	var path := save_path(slot)
	var temp_path := path + ".tmp"
	var temp := FileAccess.open(temp_path, FileAccess.WRITE)
	if temp == null:
		return ERR_CANT_OPEN
	temp.store_string(JSON.stringify(envelope, "\t"))
	temp.flush()
	temp.close()
	if FileAccess.file_exists(path):
		var backup_error := DirAccess.copy_absolute(path, path + ".bak")
		if backup_error != OK:
			DirAccess.remove_absolute(temp_path)
			return backup_error
	var replace_error := DirAccess.rename_absolute(temp_path, path)
	if replace_error != OK:
		DirAccess.remove_absolute(temp_path)
	return replace_error


func _migrate_save(envelope: Dictionary) -> Dictionary:
	var raw_version: Variant = envelope.get("schema_version", null)
	if (typeof(raw_version) != TYPE_INT and typeof(raw_version) != TYPE_FLOAT) or int(raw_version) != raw_version or int(raw_version) > SAVE_SCHEMA_VERSION or int(raw_version) < 1:
		return {}
	var snapshot_data: Variant = envelope.get("snapshot", null)
	if typeof(snapshot_data) != TYPE_DICTIONARY:
		return {}
	return {"snapshot": (snapshot_data as Dictionary).duplicate(true)}


func _notify_save_error(message: String) -> void:
	if not is_inside_tree():
		return
	var controller := get_tree().get_first_node_in_group("presentation_controller")
	if controller != null and controller.has_method("show_toast"):
		controller.call("show_toast", message, true)


func _dialogue_is_active() -> bool:
	if not is_inside_tree():
		return false
	var controller := get_tree().get_first_node_in_group("dialogue_controller")
	return controller != null and controller.has_method("is_active") and bool(controller.call("is_active"))


func replace_snapshot(data: Dictionary) -> Error:
	if not SerializationUtil.has_valid_string(data, "game_version"):
		return ERR_INVALID_DATA
	if not SerializationUtil.has_valid_int(data, "world_seed") or not SerializationUtil.has_valid_int(data, "current_slot"):
		return ERR_INVALID_DATA
	if not SerializationUtil.has_valid_dictionary(data, "player"):
		return ERR_INVALID_DATA
	if not SerializationUtil.has_valid_array(data, "maps") or not SerializationUtil.has_valid_array(data, "npcs"):
		return ERR_INVALID_DATA

	var next_player := PlayerState.from_dict(data.get("player", {}) as Dictionary)
	if next_player == null:
		return ERR_INVALID_DATA
	if not _validate_player_containers(next_player):
		return ERR_INVALID_DATA
	var next_maps: Dictionary[StringName, MapState] = {}
	for raw_map: Variant in data.get("maps", []) as Array:
		if typeof(raw_map) != TYPE_DICTIONARY:
			return ERR_INVALID_DATA
		var map_state := MapState.from_dict(raw_map as Dictionary)
		if map_state == null or next_maps.has(map_state.map_id):
			return ERR_INVALID_DATA
		next_maps[map_state.map_id] = map_state
	if next_maps.is_empty() or not next_maps.has(next_player.map_id):
		return ERR_INVALID_DATA
	var next_npcs: Dictionary[StringName, NpcState] = {}
	for raw_npc: Variant in data.get("npcs", []) as Array:
		if typeof(raw_npc) != TYPE_DICTIONARY:
			return ERR_INVALID_DATA
		var npc_state := NpcState.from_dict(raw_npc as Dictionary)
		if npc_state == null or next_npcs.has(npc_state.npc_id) or not next_maps.has(npc_state.map_id):
			return ERR_INVALID_DATA
		next_npcs[npc_state.npc_id] = npc_state

	player = next_player
	maps = next_maps
	npcs = next_npcs
	world_seed = int(data.get("world_seed", 0))
	current_slot = int(data.get("current_slot", -1))
	game_version = str(data.get("game_version", game_version))
	_initialized = true
	EventBus.player_state_changed.emit(player)
	return OK


func sync_calendar_season() -> void:
	if self != GameManager or calendar == null or not is_instance_valid(CalendarManager) or not CalendarManager.is_configured():
		return
	var next_season: StringName = CalendarManager.season_id_for_month(calendar.month)
	if next_season != &"":
		calendar.set_season(next_season)

func set_npc(state: NpcState) -> Error:
	if state == null or state.npc_id == &"" or state.map_id == &"":
		return ERR_INVALID_PARAMETER
	if npcs.has(state.npc_id):
		return ERR_ALREADY_EXISTS
	if not maps.has(state.map_id):
		return ERR_DOES_NOT_EXIST
	npcs[state.npc_id] = state
	return OK


func get_npc(npc_id: StringName) -> NpcState:
	return npcs.get(npc_id, null) as NpcState


func _initialize_npcs() -> void:
	npcs.clear()
	var schedule_ids: Array[StringName] = []
	schedule_ids.assign(DataCatalog.npc_schedules.keys())
	schedule_ids.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	for schedule_id: StringName in schedule_ids:
		var schedule := DataCatalog.get_npc_schedule(schedule_id)
		if schedule == null:
			continue
		var npc_state := NpcState.new()
		npc_state.npc_id = schedule.npc_id
		npc_state.schedule_id = schedule.id
		npc_state.map_id = schedule.fallback_map_id
		npc_state.cell = schedule.fallback_cell
		npc_state.behavior_id = schedule.fallback_behavior_id
		npc_state.target_cell = schedule.fallback_cell
		npcs[npc_state.npc_id] = npc_state
		_apply_npc_schedule(schedule, npc_state)
	EventBus.npc_states_changed.emit()


func _refresh_npc_schedules() -> void:
	if calendar == null:
		return
	var changed := false
	for npc_state: NpcState in npcs.values():
		var schedule := DataCatalog.get_npc_schedule(npc_state.schedule_id)
		if schedule != null and _apply_npc_schedule(schedule, npc_state):
			changed = true
	if changed:
		EventBus.npc_states_changed.emit()


func _apply_npc_schedule(schedule: NpcSchedule, npc_state: NpcState) -> bool:
	if schedule == null or npc_state == null or calendar == null:
		return false
	var assignment := npc_assignment(schedule)
	var next_event: StringName = assignment["event_id"] as StringName
	var next_map: StringName = assignment["map_id"] as StringName
	var previous_map := npc_state.map_id
	if previous_map != next_map and npc_portal_route(previous_map, next_map).is_empty():
		return false
	npc_state.behavior_id = assignment["behavior_id"] as StringName
	npc_state.target_cell = assignment["cell"] as Vector2i
	npc_state.target_spawn_id = assignment["spawn_id"] as StringName
	if npc_state.current_event_id == next_event and npc_state.map_id == next_map:
		return false
	if npc_state.map_id != next_map:
		npc_state.map_id = next_map
		npc_state.cell = npc_portal_arrival_cell(previous_map, next_map, npc_state.target_cell)
	npc_state.current_event_id = next_event
	return true


func npc_assignment(schedule: NpcSchedule) -> Dictionary:
	if schedule == null or calendar == null:
		return {}
	var event := npc_active_event(schedule)
	if event == null:
		return {"event_id": &"fallback", "map_id": schedule.fallback_map_id, "cell": schedule.fallback_cell, "spawn_id": &"", "behavior_id": schedule.fallback_behavior_id}
	return {"event_id": event.id, "map_id": event.map_id, "cell": event.target_cell, "spawn_id": event.target_spawn_id, "behavior_id": event.behavior_id}


func npc_active_event(schedule: NpcSchedule) -> NpcScheduleEvent:
	if schedule == null or calendar == null:
		return null
	var minute := calendar.minute_of_day()
	var matches: Array[NpcScheduleEvent] = []
	for event: NpcScheduleEvent in schedule.events:
		if event == null:
			continue
		if event.contains_minute(minute) and event.matches_date(calendar.season(), calendar.month, calendar.weekday):
			matches.append(event)
			continue
		var previous := _previous_npc_date()
		if event.contains_minute(minute, true) and event.matches_date(previous.season_id, previous.month, previous.weekday):
			matches.append(event)
	if matches.is_empty():
		return null
	matches.sort_custom(func(left: NpcScheduleEvent, right: NpcScheduleEvent) -> bool:
		if left.priority != right.priority:
			return left.priority > right.priority
		if left.start_minute != right.start_minute:
			return left.start_minute > right.start_minute
		return String(left.id) < String(right.id)
	)
	return matches[0]


func npc_portal_route(from_map: StringName, to_map: StringName) -> Array[StringName]:
	if from_map == &"" or to_map == &"":
		return []
	if from_map == to_map:
		return [from_map]
	var queue: Array[StringName] = [from_map]
	var previous: Dictionary[StringName, StringName] = {from_map: &""}
	while not queue.is_empty():
		var current: StringName = queue.pop_front()
		for neighbor_variant: Variant in NPC_PORTAL_GRAPH.get(current, []):
			var neighbor := neighbor_variant as StringName
			if previous.has(neighbor):
				continue
			previous[neighbor] = current
			if neighbor == to_map:
				var route: Array[StringName] = [to_map]
				var cursor: StringName = current
				while cursor != &"":
					route.push_front(cursor)
					cursor = previous.get(cursor, &"") as StringName
				return route
			queue.append(neighbor)
	return []


func npc_portal_arrival_cell(from_map: StringName, to_map: StringName, fallback: Vector2i) -> Vector2i:
	var route := npc_portal_route(from_map, to_map)
	if route.size() < 2:
		return fallback
	return NPC_PORTAL_ARRIVAL_CELLS.get("%s>%s" % [route[route.size() - 2], to_map], fallback)


func _previous_npc_date() -> Dictionary:
	var previous_day := calendar.day - 1
	var previous_month := calendar.month
	if previous_day < 1:
		previous_month = 12 if previous_month == 1 else previous_month - 1
		previous_day = CalendarState.DAYS_PER_MONTH
	var season_index := floori(float(previous_month - 1) / 3.0)
	return {"month": previous_month, "day": previous_day, "weekday": 7 if calendar.weekday == 1 else calendar.weekday - 1, "season_id": CalendarState.SEASONS[season_index]}


func startup_summary() -> String:
	if not _initialized:
		return "state=not_initialized"
	return "seed=%d map=%s units=%d slots=%d/%d hp=%d stamina=%d gold=%d" % [
		world_seed,
		player.map_id,
		player.used_slot_count(),
		player.used_slot_count(),
		player.backpack_state.capacity(&"inventory") + player.backpack_state.capacity(&"toolbar") + player.backpack_state.capacity(&"itembar"),
		player.health,
		player.stamina,
		player.gold,
	]


func used_inventory_slots() -> int:
	return player.used_inventory_slots() if player != null else 0


func used_slot_count() -> int:
	return player.used_slot_count() if player != null else 0


func _validate_player_containers(next_player: PlayerState) -> bool:
	if not DataCatalog.is_ready_for_game():
		return false
	for container_id: StringName in [&"inventory", &"toolbar", &"itembar"]:
		for index: int in next_player.backpack_state.capacity(container_id):
			var slot := next_player.backpack_state.get_slot(container_id, index)
			var meta := DataCatalog.get_item(slot.item_id) if slot != null and not slot.is_empty() else null
			if not next_player.container_accepts_slot(container_id, slot, meta):
				return false
	return true
