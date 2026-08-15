class_name GameManagerService
extends Node

const DEFAULT_WORLD_SEED := 12031992
const DEFAULT_TIME_SCALE := 1.2

@export_category("New Game")
@export var default_world_seed: int = DEFAULT_WORLD_SEED
@export var player_state_template: PlayerState = preload("res://data/player/default_player_state.tres")
@export_category("Time")
@export_range(0.1, 120.0, 0.1, "or_greater") var initial_time_scale: float = DEFAULT_TIME_SCALE

var player: PlayerState = null
var maps: Dictionary[StringName, MapState] = {}
var npcs: Dictionary[StringName, NpcState] = {}
var world_seed: int = 0
var current_slot: int = -1
var game_version: String = "0.1.0"
var calendar: CalendarState = CalendarState.new()
var time_scale: float = DEFAULT_TIME_SCALE
var _running: bool = false
var _pause_reasons: Dictionary[StringName, bool] = {}
var _time_accumulator: float = 0.0
var _ending_day: bool = false

var _initialized: bool = false


func _ready() -> void:
	var time_error := configure_time_scale(initial_time_scale)
	if time_error != OK:
		push_error("[GameManager] invalid initial time scale: %s" % initial_time_scale)
		return
	if DataCatalog.is_ready_for_game():
		var error: Error = new_game(default_world_seed)
		if error != OK:
			push_error("[GameManager] failed to create default new game: %s" % error_string(error))


func _process(delta: float) -> void:
	if not can_advance() or delta <= 0.0:
		return
	_time_accumulator += delta * time_scale
	var whole_minutes := floori(_time_accumulator)
	if whole_minutes <= 0:
		return
	_time_accumulator -= whole_minutes
	advance_minutes(whole_minutes)


func configure_time_scale(value: float) -> Error:
	if value <= 0.0 or is_nan(value) or is_inf(value):
		return ERR_INVALID_PARAMETER
	time_scale = value
	_time_accumulator = 0.0
	return OK


func new_game(p_seed: int) -> Error:
	if not DataCatalog.is_ready_for_game():
		return ERR_UNCONFIGURED

	var next_player := PlayerState.new()
	var player_error := next_player.initialize(player_state_template)
	if player_error != OK:
		return player_error
	if not _validate_player_containers(next_player):
		return ERR_INVALID_DATA

	var next_maps: Dictionary[StringName, MapState] = {}
	for map_id: StringName in [&"farm", &"field", &"cabin"]:
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
	if not _initialized:
		return ERR_UNCONFIGURED
	_complete_day()
	return OK


func advance_minutes(minutes: int) -> Error:
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
			_complete_day()
	return OK


func request_end_day() -> Error:
	if not _initialized:
		return ERR_UNCONFIGURED
	_complete_day()
	return OK


func _complete_day() -> void:
	if _ending_day or not _initialized:
		return
	_ending_day = true
	var previous_day := calendar.day
	calendar.add_minutes((24 * 60) - calendar.minute_of_day())
	sync_calendar_season()
	EventBus.day_advanced.emit(previous_day, calendar.day)
	if player != null:
		player.restore_for_new_day()
		player.map_id = &"cabin"
		player.spawn_id = &"wake"
		EventBus.player_state_changed.emit(player)
	calendar.hour = 6
	calendar.minute = 0
	sync_calendar_season()
	if is_instance_valid(SceneManager) and SceneManager.current_map_id() != &"cabin":
		SceneManager.request_map_change(&"cabin", &"wake")
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


func replace_build_snapshot(data: Dictionary) -> Error:
	if not SerializationUtil.has_valid_dictionary(data, "game") or not SerializationUtil.has_valid_dictionary(data, "time"):
		return ERR_INVALID_DATA
	var time_data := data.get("time", {}) as Dictionary
	var next_calendar := CalendarState.from_dict(time_data.get("calendar", {}) as Dictionary)
	var raw_time_scale: Variant = time_data.get("time_scale", initial_time_scale)
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
	time_scale = float(time_data.get("time_scale", initial_time_scale))
	_running = bool(time_data.get("running", false))
	_pause_reasons = next_pause_reasons
	_time_accumulator = 0.0
	_ending_day = false
	return OK


func save_slot(_slot: int = 0) -> Error:
	return ERR_UNAVAILABLE


func load_slot(_slot: int = 0) -> Error:
	return ERR_UNAVAILABLE


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
	if self != GameManager or calendar == null or not is_instance_valid(WeatherManager) or not WeatherManager.is_configured():
		return
	var next_season: StringName = WeatherManager.season_id_for_month(calendar.month)
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
