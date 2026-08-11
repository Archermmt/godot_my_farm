class_name GameManagerService
extends Node

const DEFAULT_WORLD_SEED := 12031992

var player: PlayerState = null
var maps: Dictionary[StringName, MapState] = {}
var npcs: Dictionary[StringName, NpcState] = {}
var world_seed: int = 0
var current_slot: int = -1
var game_version: String = "0.1.0"
var calendar: CalendarState = CalendarState.new()
var time_scale: float = 60.0
var _running: bool = false
var _pause_reasons: Dictionary[StringName, bool] = {}

var _catalog_service: DataCatalogService = null
var _event_bus_service: EventBusService = null
var _initialized: bool = false


func _ready() -> void:
	configure(DataCatalog, EventBus)
	if _catalog_service != null and _catalog_service.is_ready_for_game():
		var error: Error = new_game(DEFAULT_WORLD_SEED)
		if error != OK:
			push_error("[GameManager] failed to create default new game: %s" % error_string(error))


func configure(catalog_service: DataCatalogService, event_bus_service: EventBusService = null) -> void:
	_catalog_service = catalog_service
	_event_bus_service = event_bus_service


func new_game(p_seed: int) -> Error:
	if _catalog_service == null or not _catalog_service.is_ready_for_game():
		return ERR_UNCONFIGURED

	var next_player := PlayerState.new()
	var player_error := next_player.initialize(_catalog_service)
	if player_error != OK:
		return player_error

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
	_running = false
	_pause_reasons.clear()
	_initialized = true
	if _event_bus_service != null:
		_event_bus_service.player_state_changed.emit(player)
	print("[GameManager] new game | seed=%d map=%s inventory=%d/%d" % [
		world_seed,
		player.map_id,
		player.used_slot_count(),
		player.inventory.capacity() + player.toolbar.capacity() + player.itembar.capacity(),
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
	_running = false
	_pause_reasons.clear()
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
	var raw_time_scale: Variant = time_data.get("time_scale", 60.0)
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
	time_scale = float(time_data.get("time_scale", 60.0))
	_running = bool(time_data.get("running", false))
	_pause_reasons = next_pause_reasons
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
	if _event_bus_service != null:
		_event_bus_service.player_state_changed.emit(player)
	return OK

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
		player.itembar.count_item(PlayerState.INITIAL_SEED_ID) + PlayerState.INITIAL_TOOL_IDS.size(),
		player.used_slot_count(),
		player.inventory.capacity() + player.toolbar.capacity() + player.itembar.capacity(),
		player.health,
		player.stamina,
		player.gold,
	]


func used_inventory_slots() -> int:
	return player.used_inventory_slots() if player != null else 0


func used_slot_count() -> int:
	return player.used_slot_count() if player != null else 0


func _validate_player_containers(next_player: PlayerState) -> bool:
	for container_id: StringName in [&"inventory", &"toolbar", &"itembar"]:
		var container := next_player.get_container(container_id)
		for stack: ItemStack in container.slots:
			var meta := _catalog_service.get_item(stack.item_id) if not stack.is_empty() else null
			if not next_player.container_accepts_stack(container_id, stack, meta):
				return false
	return true
