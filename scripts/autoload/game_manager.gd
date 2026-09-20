class_name GameManagerService
extends Node

const SAVE_SCHEMA_VERSION := 1
const SAVE_DIRECTORY := "user://saves"
const SAVE_FILE_TEMPLATE := SAVE_DIRECTORY + "/slot_%d.json"

## Log verbosity is configured by GameConfig.verbose_level.
## Higher levels include all messages from lower levels.
enum LogLevel {
	NONE = 0,
	ERROR = 1,
	WARN = 2,
	INFO = 3,
	DEBUG = 4,
}

var config: GameConfig:
	get:
		return DataCatalog.config
var player: FarmPlayer = null
var map_states: Dictionary[StringName, MapState] = {}
var npc_states: Dictionary[StringName, NpcState] = {}
var npcs: Dictionary[StringName, FarmNpc] = {}
var current_slot: int = -1
var game_version: String = "0.1.0"
var calendar: CalendarManagerService:
	get:
		return CalendarManager.calendar if is_instance_valid(CalendarManager) else null
var _save_in_progress := false
var save_directory: String = SAVE_DIRECTORY
var _initialized: bool = false


func _ready() -> void:
	pass


func debug(message: String) -> void:
	_write_log(LogLevel.DEBUG, message)


func info(message: String) -> void:
	_write_log(LogLevel.INFO, message)


func warn(message: String) -> void:
	_write_log(LogLevel.WARN, message)


func error(message: String) -> void:
	_write_log(LogLevel.ERROR, message)


func _write_log(level: int, message: String) -> void:
	if level > _configured_log_level() or level == LogLevel.NONE:
		return
	print(message)


func _configured_log_level() -> int:
	if is_instance_valid(DataCatalog) and DataCatalog.config != null:
		return DataCatalog.config.verbose_level
	return LogLevel.INFO


func _exit_tree() -> void:
	_clear_npcs()
	player = null


func _clear_npcs() -> void:
	for actor: FarmNpc in npcs.values():
		if is_instance_valid(actor):
			actor.queue_free()
	npcs.clear()


func setup(next_player: FarmPlayer) -> Error:
	if next_player == null:
		return ERR_INVALID_PARAMETER
	var catalog_errors := DataCatalog.setup()
	if not catalog_errors.is_empty():
		return ERR_UNCONFIGURED
	player = next_player
	map_states.clear()
	npc_states.clear()
	var initialized_npcs: Dictionary[StringName, bool] = {}
	for npc_id: StringName in DataCatalog.config.npc_schedules:
		if initialized_npcs.has(npc_id):
			continue
		var entries: Array = DataCatalog.config.npc_schedules[npc_id]
		if entries.is_empty():
			continue
		var npc_state := NpcState.from_schedule(entries[0], npc_id)
		if npc_state != null:
			npc_states[npc_state.npc_id] = npc_state
			initialized_npcs[npc_id] = true
	_initialized = true
	GameManager.info(
		(
			"[GameManager] new game | seed=%d map=%s inventory=%d/%d"
			% [
				CalendarManager.world_seed,
				MapManager.current_map_id(),
				(
					0
					if not is_instance_valid(player) or player.backpack == null
					else (
						player.backpack.used_slot_count(&"main_space")
						+ player.backpack.used_slot_count(&"toolbar")
						+ player.backpack.used_slot_count(&"itembar")
					)
				),
				(
					0
					if not is_instance_valid(player) or player.backpack == null
					else (
						player.backpack.capacity(&"main_space")
						+ player.backpack.capacity(&"toolbar")
						+ player.backpack.capacity(&"itembar")
					)
				),
			]
		)
	)
	return OK


func snapshot() -> Dictionary:
	if not _initialized:
		return {}
	if is_instance_valid(MapManager) and MapManager.current_map() != null:
		var live_map := MapManager.current_map()
		map_states[live_map.map_id] = live_map.to_state()
	for npc: FarmNpc in npcs.values():
		if is_instance_valid(npc) and npc.state != null:
			npc_states[npc.state.npc_id] = npc.to_state()
	var map_data: Dictionary = {}
	for map_id: StringName in map_states:
		map_data[String(map_id)] = map_states[map_id].to_dict()
	var npc_data: Dictionary = {}
	for npc_id: StringName in npc_states:
		npc_data[String(npc_id)] = npc_states[npc_id].to_dict()
	return (
		{
			"game_version": game_version,
			"current_slot": current_slot,
			"player": player.to_dict() if is_instance_valid(player) else {},
			"map_manager": MapManager.to_dict(),
			"calendar_manager": CalendarManager.to_dict(),
			"item_manager": ItemManager.to_dict(),
			"map_states": map_data,
			"npc_states": npc_data,
		}
		. duplicate(true)
	)


func save_game(slot: int = 0) -> Error:
	if not _initialized or _save_in_progress or slot < 0:
		return ERR_BUSY if _save_in_progress else ERR_UNAVAILABLE
	if self == GameManager and is_instance_valid(MapManager) and MapManager.is_transitioning():
		return ERR_BUSY
	_save_in_progress = true
	var previous_slot := current_slot
	current_slot = slot
	var snapshot_data := snapshot()
	var result: Error = ERR_UNAVAILABLE
	if not snapshot_data.is_empty():
		var envelope := (
			{
				"schema_version": SAVE_SCHEMA_VERSION,
				"saved_at": Time.get_datetime_string_from_system(true),
				"snapshot": snapshot_data,
			}
			. duplicate(true)
		)
		var save_directory_path := ProjectSettings.globalize_path(save_directory)
		var directory_error := DirAccess.make_dir_recursive_absolute(save_directory_path)
		if directory_error == OK or DirAccess.dir_exists_absolute(save_directory_path):
			var path := save_path(slot)
			var temp_path := path + ".tmp"
			var temp := FileAccess.open(temp_path, FileAccess.WRITE)
			if temp != null:
				temp.store_string(JSON.stringify(envelope, "\t"))
				temp.flush()
				temp.close()
				result = OK
				if FileAccess.file_exists(path):
					result = DirAccess.copy_absolute(path, path + ".bak")
				if result == OK:
					result = DirAccess.rename_absolute(temp_path, path)
				if result != OK and FileAccess.file_exists(temp_path):
					DirAccess.remove_absolute(temp_path)
	_save_in_progress = false
	if result == OK:
		EventBus.save_completed.emit(slot)
	else:
		current_slot = previous_slot
		notify_error("SAVE FAILED")
	return result


func load_game(slot: int = 0) -> Error:
	if not _initialized:
		return ERR_UNAVAILABLE
	if _save_in_progress or slot < 0:
		return ERR_BUSY if _save_in_progress else ERR_INVALID_PARAMETER
	if not FileAccess.file_exists(save_path(slot)):
		notify_error("NO SAVE FOUND")
		return ERR_FILE_NOT_FOUND
	if self == GameManager and is_instance_valid(MapManager) and MapManager.is_transitioning():
		return ERR_BUSY
	var file := FileAccess.open(save_path(slot), FileAccess.READ)
	if file == null:
		return ERR_CANT_OPEN
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		notify_error("SAVE DATA CORRUPTED")
		return ERR_INVALID_DATA
	var parsed: Variant = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		notify_error("SAVE DATA CORRUPTED")
		return ERR_INVALID_DATA
	var envelope := parsed as Dictionary
	var raw_version: Variant = envelope.get("schema_version", null)
	var snapshot_value: Variant = envelope.get("snapshot", null)
	if (
		(typeof(raw_version) != TYPE_INT and typeof(raw_version) != TYPE_FLOAT)
		or int(raw_version) != raw_version
		or int(raw_version) > SAVE_SCHEMA_VERSION
		or int(raw_version) < 1
		or typeof(snapshot_value) != TYPE_DICTIONARY
	):
		notify_error("UNSUPPORTED SAVE VERSION")
		return ERR_INVALID_DATA
	var snapshot_data := (snapshot_value as Dictionary).duplicate(true)
	if ItemManager.from_dict(snapshot_data.get("item_manager", {}) as Dictionary) != OK:
		notify_error("SAVE DATA INVALID")
		return ERR_INVALID_DATA
	if CalendarManager.from_dict(snapshot_data.get("calendar_manager", {}) as Dictionary) != OK:
		notify_error("SAVE DATA INVALID")
		return ERR_INVALID_DATA
	if MapManager.from_dict(snapshot_data.get("map_manager", {}) as Dictionary) != OK:
		notify_error("SAVE DATA INVALID")
		return ERR_INVALID_DATA
	var result: Error = OK
	if (
		not SerializationUtil.has_valid_string(snapshot_data, "game_version")
		or not SerializationUtil.has_valid_int(snapshot_data, "current_slot")
		or not SerializationUtil.has_valid_dictionary(snapshot_data, "player")
		or not SerializationUtil.has_valid_dictionary(snapshot_data, "map_states")
		or not SerializationUtil.has_valid_dictionary(snapshot_data, "npc_states")
	):
		result = ERR_INVALID_DATA
	map_states.clear()
	for raw_map: Variant in (snapshot_data.get("map_states", {}) as Dictionary).values():
		if typeof(raw_map) != TYPE_DICTIONARY:
			result = ERR_INVALID_DATA
			break
		var map_state := MapState.from_dict(raw_map as Dictionary)
		if map_state == null or map_states.has(map_state.map_id):
			result = ERR_INVALID_DATA
			break
		map_states[map_state.map_id] = map_state
	if map_states.is_empty():
		result = ERR_INVALID_DATA
	npc_states.clear()
	for raw_npc: Variant in (snapshot_data.get("npc_states", {}) as Dictionary).values():
		if typeof(raw_npc) != TYPE_DICTIONARY:
			result = ERR_INVALID_DATA
			break
		var npc_state := NpcState.from_dict(raw_npc as Dictionary)
		if npc_state == null or npc_states.has(npc_state.npc_id):
			result = ERR_INVALID_DATA
			break
		if not map_states.has(npc_state.map_id):
			var missing_map_state := MapState.new()
			missing_map_state.map_id = npc_state.map_id
			map_states[npc_state.map_id] = missing_map_state
		npc_states[npc_state.npc_id] = npc_state
	if (
		not is_instance_valid(player)
		or result != OK
		or player.from_dict(snapshot_data.get("player", {}) as Dictionary) != OK
	):
		result = ERR_INVALID_DATA
	if result != OK:
		notify_error("SAVE DATA INVALID")
		return result
	_clear_npcs()
	current_slot = int(snapshot_data.get("current_slot", -1))
	game_version = str(snapshot_data.get("game_version", game_version))
	_initialized = true
	if self == GameManager and is_instance_valid(MapManager) and MapManager.current_map() != null:
		var saved_map_id := StringName(
			str(snapshot_data.get("map_manager", {}).get("current_map_id", config.player_map_id))
		)
		var map_error := await MapManager._change_map(saved_map_id, &"", false)
		if map_error != OK:
			notify_error("MAP RESTORE FAILED")
			return map_error
	current_slot = slot
	EventBus.load_completed.emit(slot)
	return OK


func notify_error(message: String) -> void:
	if not is_inside_tree():
		return
	var controller := get_tree().get_first_node_in_group("presentation_controller")
	if controller != null and controller.has_method("show_toast"):
		controller.call("show_toast", message, true)


func save_path(slot: int = 0) -> String:
	return "%s/slot_%d.json" % [save_directory, maxi(0, slot)]


func is_initialized() -> bool:
	return _initialized
