class_name GameManagerService
extends Node

const SAVE_SCHEMA_VERSION := 1
const SAVE_DIRECTORY := "user://saves"
const SAVE_FILE_TEMPLATE := SAVE_DIRECTORY + "/slot_%d.json"
const NPC_SCENE := preload("res://scenes/actors/npcs/npc.tscn")

var config: GameConfig:
	get:
		return DataCatalog.config

var player: FarmPlayer = null
var _player_state: PlayerState = null
var _backpack_state: BackpackState = null
var maps: Dictionary[StringName, MapState] = {}
var npcs: Dictionary[StringName, NpcState] = {}
var world_seed: int = 0
var current_slot: int = -1
var game_version: String = "0.1.0"
var calendar: CalendarManagerService:
	get:
		return CalendarManager.calendar if is_instance_valid(CalendarManager) else null
var _save_in_progress := false
var save_directory: String = SAVE_DIRECTORY

var _initialized: bool = false
var _npc_actors: Dictionary[StringName, FarmNpc] = {}
var _npcs_by_map: Dictionary[StringName, Dictionary] = {}

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


func _ready() -> void:
	if not EventBus.map_changed.is_connected(_sync_npc_actors):
		EventBus.map_changed.connect(_sync_npc_actors)
	if not EventBus.time_advanced.is_connected(_sync_npc_actors):
		EventBus.time_advanced.connect(_sync_npc_actors)
	if not EventBus.npc_states_changed.is_connected(_sync_npc_actors):
		EventBus.npc_states_changed.connect(_sync_npc_actors)
	if DataCatalog.validate().is_empty():
		var error: Error = new_game(config.default_world_seed)
		if error != OK:
			push_error("[GameManager] failed to create default new game: %s" % error_string(error))


func _exit_tree() -> void:
	_clear_npc_actors()
	_npcs_by_map.clear()
	player = null


func register_player(next_player: FarmPlayer) -> Error:
	if next_player == null:
		return ERR_INVALID_PARAMETER
	if player != null and player != next_player and is_instance_valid(player):
		return ERR_ALREADY_IN_USE
	player = next_player
	_bind_runtime_state()
	return OK


func player_state() -> PlayerState:
	return player.state if is_instance_valid(player) else _player_state


func _bind_runtime_state() -> void:
	if not is_instance_valid(player):
		return
	if _player_state != null:
		player.setup(_player_state)
	if _backpack_state != null and player.backpack != null:
		player.backpack.setup(_backpack_state)


func _sync_npc_actors(_unused = null) -> void:
	var actor_host := MapManager.actor_host()
	var current_map := MapManager.current_map()
	if actor_host == null or current_map == null:
		return
	for npc_id: StringName in _npc_actors.keys():
		var npc_state := get_npc(npc_id)
		if npc_state == null or npc_state.map_id != current_map.map_id:
			var actor := _npc_actors[npc_id]
			_npc_actors.erase(npc_id)
			if is_instance_valid(actor):
				actor.queue_free()
	var map_npcs: Dictionary = _npcs_by_map.get(current_map.map_id, {})
	for npc_state: NpcState in map_npcs.values():
		var existing := _npc_actors.get(npc_state.npc_id, null) as FarmNpc
		if existing != null and is_instance_valid(existing):
			existing.refresh_target()
			continue
		var actor := NPC_SCENE.instantiate() as FarmNpc
		if actor == null:
			continue
		actor_host.add_child(actor)
		if actor.bind(npc_state, current_map) != OK:
			actor.queue_free()
			continue
		actor.name = String(npc_state.npc_id)
		_npc_actors[npc_state.npc_id] = actor


func _clear_npc_actors() -> void:
	for actor: FarmNpc in _npc_actors.values():
		if is_instance_valid(actor):
			actor.queue_free()
	_npc_actors.clear()


func _index_npc(npc_state: NpcState) -> void:
	var map_npcs: Dictionary = _npcs_by_map.get(npc_state.map_id, {})
	map_npcs[npc_state.npc_id] = npc_state
	_npcs_by_map[npc_state.map_id] = map_npcs


func new_game(p_seed: int) -> Error:
	if not DataCatalog.validate().is_empty():
		return ERR_UNCONFIGURED

	var next_player := _create_player_state(true)
	if next_player == null:
		return ERR_INVALID_DATA
	var next_backpack := _create_backpack_state()
	if next_backpack == null:
		return ERR_UNCONFIGURED
	next_backpack.ensure_layout()
	if not _validate_player_containers(next_backpack):
		return ERR_INVALID_DATA

	var next_maps: Dictionary[StringName, MapState] = {}
	for map_id: StringName in [&"farm", &"field", &"beach"]:
		var map_state := MapState.new()
		map_state.map_id = map_id
		next_maps[map_id] = map_state

	ItemManager.reset_unique_count()
	_player_state = next_player
	_backpack_state = next_backpack
	maps = next_maps
	npcs = {}
	_npcs_by_map.clear()
	world_seed = p_seed
	current_slot = -1
	CalendarManager.reset_calendar(p_seed)
	CalendarManager.refresh()
	_initialize_npcs()
	_initialized = true
	_bind_runtime_state()
	EventBus.player_state_changed.emit(_player_state)
	print(
		(
			"[GameManager] new game | seed=%d map=%s inventory=%d/%d"
			% [
				world_seed,
				MapManager.current_map_id(),
				(
					_backpack_state.used_slot_count(&"main_space")
					+ _backpack_state.used_slot_count(&"toolbar")
					+ _backpack_state.used_slot_count(&"itembar")
				),
				(
					_backpack_state.capacity(&"main_space")
					+ _backpack_state.capacity(&"toolbar")
					+ _backpack_state.capacity(&"itembar")
				),
			]
		)
	)
	return OK


func _create_backpack_state(allow_legacy_template: bool = true) -> BackpackState:
	if config == null:
		return null
	if allow_legacy_template and config.backpack_state_template != null:
		return config.backpack_state_template.duplicate(true) as BackpackState
	var state := BackpackState.new(
		config.backpack_main_space_capacity, config.backpack_toolbar_capacity, config.backpack_itembar_capacity
	)
	for slot_id: StringName in config.backpack_initial_slots:
		var slot := config.backpack_initial_slots[slot_id] as BackpackSlot
		if slot != null:
			state.slots[slot_id] = slot.duplicate_slot()
	state.ensure_layout()
	return state


func _create_player_state(allow_legacy_template: bool = true) -> PlayerState:
	if config == null:
		return null
	if allow_legacy_template and config.player_state_template != null:
		return config.player_state_template.duplicate(true) as PlayerState
	var state := PlayerState.new()
	state.position = Vector2.ZERO
	state.facing = config.player_facing
	state.max_health = config.player_max_health
	state.health = clampi(config.player_initial_health, 0, state.max_health)
	state.max_energy = config.player_max_energy
	state.energy = clampi(config.player_initial_energy, 0, state.max_energy)
	state.gold = maxi(0, config.player_initial_gold)
	state.run_speed = config.player_run_speed
	state.walk_speed = config.player_walk_speed
	state.pickup_radius = config.player_pickup_radius
	state.pickup_collect_distance = config.player_pickup_collect_distance
	state.trace_delay = config.player_trace_delay.duplicate(true)
	state.pickup_speed_curve = config.player_pickup_speed_curve
	state.indoor_camera_zoom = config.player_indoor_camera_zoom
	state.camera_zoom_duration = config.player_camera_zoom_duration
	return state


func is_initialized() -> bool:
	return _initialized


func reset() -> void:
	CalendarManager.stop()
	CalendarManager.reset_calendar(0)
	CalendarManager.refresh()
	player = null
	_npcs_by_map.clear()
	_backpack_state = null
	maps.clear()
	npcs.clear()
	world_seed = 0
	current_slot = -1
	_initialized = false


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
	return (
		{
			"game_version": game_version,
			"world_seed": world_seed,
			"current_slot": current_slot,
			"current_map_id": String(MapManager.current_map_id()),
			"player": player_state().to_dict(),
			"backpack": (
				player.backpack.backpack_state.to_dict()
				if is_instance_valid(player) and player.backpack != null and player.backpack.backpack_state != null
				else _backpack_state.to_dict()
			),
			"maps": map_data,
			"npcs": npc_data,
		}
		. duplicate(true)
	)


func time_snapshot() -> Dictionary:
	return (
		{
			"calendar": calendar.to_dict(),
			"time_scale": CalendarManager.time_scale,
			"running": CalendarManager.is_running(),
			"pause_reasons": SerializationUtil.string_name_array_to_strings(CalendarManager.pause_reasons()),
		}
		. duplicate(true)
	)


func can_snapshot() -> bool:
	return _initialized


func build_snapshot() -> Dictionary:
	if not can_snapshot():
		return {}
	return (
		{
			"game": snapshot(),
			"time": time_snapshot(),
		}
		. duplicate(true)
	)


func save_path(slot: int = 0) -> String:
	return "%s/slot_%d.json" % [save_directory, maxi(0, slot)]


func replace_build_snapshot(data: Dictionary) -> Error:
	if (
		not SerializationUtil.has_valid_dictionary(data, "game")
		or not SerializationUtil.has_valid_dictionary(data, "time")
	):
		return ERR_INVALID_DATA
	var time_data := data.get("time", {}) as Dictionary
	var next_calendar := CalendarManagerService.new()
	var calendar_error := next_calendar.load_dict(time_data.get("calendar", {}) as Dictionary)
	var raw_time_scale: Variant = time_data.get("time_scale", config.initial_time_scale)
	if (
		calendar_error != OK
		or (typeof(raw_time_scale) != TYPE_FLOAT and typeof(raw_time_scale) != TYPE_INT)
		or float(raw_time_scale) <= 0.0
		or not SerializationUtil.has_valid_bool(time_data, "running")
		or not SerializationUtil.has_valid_array(time_data, "pause_reasons")
	):
		return ERR_INVALID_DATA
	var next_pause_reasons: Dictionary[StringName, bool] = {}
	for raw_reason: Variant in time_data.get("pause_reasons", []) as Array:
		if typeof(raw_reason) != TYPE_STRING or String(raw_reason).is_empty():
			return ERR_INVALID_DATA
		next_pause_reasons[StringName(str(raw_reason))] = true
	var game_error := replace_snapshot(data.get("game", {}) as Dictionary)
	if game_error != OK:
		return game_error
	CalendarManager.load_dict(next_calendar.to_dict())
	CalendarManager.world_seed = int((data.get("game", {}) as Dictionary).get("world_seed", world_seed))
	CalendarManager.refresh()
	_refresh_npc_schedules()
	CalendarManager.configure_time_scale(float(time_data.get("time_scale", config.initial_time_scale)))
	if bool(time_data.get("running", false)):
		CalendarManager._running = true
	else:
		CalendarManager.stop()
	for reason: StringName in next_pause_reasons:
		CalendarManager.pause(reason)
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
	if (
		self == GameManager
		and is_instance_valid(MapManager)
		and (MapManager.is_transitioning() or _dialogue_is_active())
	):
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
	var envelope := (
		{
			"schema_version": SAVE_SCHEMA_VERSION,
			"saved_at": Time.get_datetime_string_from_system(true),
			"game_version": game_version,
			"snapshot": snapshot_data,
		}
		. duplicate(true)
	)
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
	if (
		(typeof(raw_version) != TYPE_INT and typeof(raw_version) != TYPE_FLOAT)
		or int(raw_version) != raw_version
		or int(raw_version) > SAVE_SCHEMA_VERSION
		or int(raw_version) < 1
	):
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
	var controller := get_tree().get_first_node_in_group("interact_manager") if is_inside_tree() else null
	return controller != null and controller.has_method("is_active") and bool(controller.call("is_active"))


func replace_snapshot(data: Dictionary) -> Error:
	if not SerializationUtil.has_valid_string(data, "game_version"):
		return ERR_INVALID_DATA
	if (
		not SerializationUtil.has_valid_int(data, "world_seed")
		or not SerializationUtil.has_valid_int(data, "current_slot")
	):
		return ERR_INVALID_DATA
	if not SerializationUtil.has_valid_dictionary(data, "player"):
		return ERR_INVALID_DATA
	if not SerializationUtil.has_valid_string(data, "current_map_id"):
		return ERR_INVALID_DATA
	if not SerializationUtil.has_valid_dictionary(data, "backpack"):
		return ERR_INVALID_DATA
	if not SerializationUtil.has_valid_array(data, "maps") or not SerializationUtil.has_valid_array(data, "npcs"):
		return ERR_INVALID_DATA

	var next_player := PlayerState.from_dict(data.get("player", {}) as Dictionary, _create_player_state(false))
	if next_player == null:
		return ERR_INVALID_DATA
	var next_backpack := BackpackState.from_dict(data.get("backpack", {}) as Dictionary)
	if next_backpack == null or not _validate_player_containers(next_backpack):
		return ERR_INVALID_DATA
	var next_maps: Dictionary[StringName, MapState] = {}
	for raw_map: Variant in data.get("maps", []) as Array:
		if typeof(raw_map) != TYPE_DICTIONARY:
			return ERR_INVALID_DATA
		var map_state := MapState.from_dict(raw_map as Dictionary)
		if map_state == null or next_maps.has(map_state.map_id):
			return ERR_INVALID_DATA
		next_maps[map_state.map_id] = map_state
	if next_maps.is_empty():
		return ERR_INVALID_DATA
	var next_npcs: Dictionary[StringName, NpcState] = {}
	for raw_npc: Variant in data.get("npcs", []) as Array:
		if typeof(raw_npc) != TYPE_DICTIONARY:
			return ERR_INVALID_DATA
		var npc_state := NpcState.from_dict(raw_npc as Dictionary)
		if npc_state == null or next_npcs.has(npc_state.npc_id) or not next_maps.has(npc_state.map_id):
			return ERR_INVALID_DATA
		next_npcs[npc_state.npc_id] = npc_state
		_index_npc(npc_state)
	ItemManager.reset_unique_count()
	for map_state: MapState in next_maps.values():
		for item_id: StringName in map_state.items:
			ItemManager.register_unique_id(item_id)

	_player_state = next_player
	MapManager.set_loaded_map_id(StringName(str(data.get("current_map_id", config.player_map_id))))
	_backpack_state = next_backpack
	maps = next_maps
	npcs = next_npcs
	world_seed = int(data.get("world_seed", 0))
	current_slot = int(data.get("current_slot", -1))
	game_version = str(data.get("game_version", game_version))
	_initialized = true
	_bind_runtime_state()
	EventBus.player_state_changed.emit(_player_state)
	return OK


func set_npc(state: NpcState) -> Error:
	if state == null or state.npc_id == &"" or state.map_id == &"":
		return ERR_INVALID_PARAMETER
	if npcs.has(state.npc_id):
		return ERR_ALREADY_EXISTS
	if not maps.has(state.map_id):
		return ERR_DOES_NOT_EXIST
	npcs[state.npc_id] = state
	_index_npc(state)
	return OK


func get_npc(npc_id: StringName) -> NpcState:
	return npcs.get(npc_id, null) as NpcState


func _initialize_npcs() -> void:
	npcs.clear()
	_npcs_by_map.clear()
	var schedule_ids: Array[StringName] = []
	schedule_ids.assign(DataCatalog.config.npc_schedules.keys())
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
		_index_npc(npc_state)
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
		var previous_map_npcs: Dictionary = _npcs_by_map.get(previous_map, {})
		previous_map_npcs.erase(npc_state.npc_id)
		npc_state.map_id = next_map
		npc_state.cell = npc_portal_arrival_cell(previous_map, next_map, npc_state.target_cell)
		_index_npc(npc_state)
	npc_state.current_event_id = next_event
	return true


func npc_assignment(schedule: NpcSchedule) -> Dictionary:
	if schedule == null or calendar == null:
		return {}
	var event := npc_active_event(schedule)
	if event == null:
		return {
			"event_id": &"fallback",
			"map_id": schedule.fallback_map_id,
			"cell": schedule.fallback_cell,
			"spawn_id": &"",
			"behavior_id": schedule.fallback_behavior_id
		}
	return {
		"event_id": event.id,
		"map_id": event.map_id,
		"cell": event.target_cell,
		"spawn_id": event.target_spawn_id,
		"behavior_id": event.behavior_id
	}


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
		if (
			event.contains_minute(minute, true)
			and event.matches_date(previous.season, previous.month, previous.weekday)
		):
			matches.append(event)
	if matches.is_empty():
		return null
	matches.sort_custom(
		func(left: NpcScheduleEvent, right: NpcScheduleEvent) -> bool:
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
		previous_day = CalendarManagerService.DAYS_PER_MONTH
	return {
		"month": previous_month,
		"day": previous_day,
		"weekday": 7 if calendar.weekday == 1 else calendar.weekday - 1,
		"season": calendar.season(previous_month)
	}


func _validate_player_containers(next_backpack: BackpackState) -> bool:
	if not DataCatalog.validate().is_empty():
		return false
	for container_id: StringName in [&"main_space", &"toolbar", &"itembar"]:
		for index: int in next_backpack.capacity(container_id):
			var slot := next_backpack.get_slot(container_id, index)
			var meta := DataCatalog.get_item(slot.item_id) if slot != null and not slot.is_empty() else null
			if slot != null and not slot.is_empty() and not _container_accepts(container_id, meta):
				return false
	return true


func _container_accepts(container_id: StringName, meta: ItemMeta) -> bool:
	if meta == null:
		return false
	if container_id == &"toolbar":
		return meta is ToolMeta
	if container_id == &"itembar":
		return not meta is ToolMeta and not meta is HarvestableMeta
	return container_id == &"main_space"
