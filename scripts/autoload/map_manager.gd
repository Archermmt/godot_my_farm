class_name MapManagerService
extends Node

const NPC_SCENES: Dictionary[StringName, PackedScene] = {
	&"npc_fisher": preload("res://scenes/actors/npcs/fisher.tscn"),
	&"npc_ranger": preload("res://scenes/actors/npcs/ranger.tscn"),
	&"npc_villager": preload("res://scenes/actors/npcs/villager.tscn"),
}

const MAP_SCENE_PATHS := {
	&"farm": "res://scenes/maps/farm/farm.tscn",
	&"field": "res://scenes/maps/field/field.tscn",
	&"beach": "res://scenes/maps/beach/beach.tscn",
}
const TRANSITION_LOCK := &"scene_transition"

var config: GameConfig:
	get:
		return DataCatalog.config
var _map_host: Node2D = null
var _transition_overlay: CanvasItem = null
var _current_map: BaseMap = null
var _transitioning := false
var _map_npcs: Dictionary[StringName, Array] = {}


func _ready() -> void:
	var scene := get_tree().current_scene
	if scene != null:
		_map_host = scene.get_node_or_null("World/MapHost") as Node2D
		_transition_overlay = scene.get_node_or_null("UILayer/TransitionOverlay") as CanvasItem
	if _transition_overlay != null:
		_transition_overlay.modulate = Color(1, 1, 1, 0)
		if _transition_overlay is Control:
			(_transition_overlay as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not EventBus.npc_change_map.is_connected(_on_npc_change_map):
		EventBus.npc_change_map.connect(_on_npc_change_map)
	if not EventBus.day_advanced.is_connected(_on_day_advanced):
		EventBus.day_advanced.connect(_on_day_advanced)


func setup() -> Error:
	var tree: SceneTree = get_tree() if is_inside_tree() else null
	if (tree == null or tree.current_scene == null) and (_map_host == null or _transition_overlay == null):
		return ERR_INVALID_PARAMETER
	if _map_host == null or _transition_overlay == null:
		var scene := tree.current_scene
		if scene != null:
			_map_host = scene.get_node_or_null("World/MapHost") as Node2D
			_transition_overlay = scene.get_node_or_null("UILayer/TransitionOverlay") as CanvasItem
	if _map_host == null or _transition_overlay == null:
		return ERR_INVALID_PARAMETER
	return OK


func _exit_tree() -> void:
	if EventBus.day_advanced.is_connected(_on_day_advanced):
		EventBus.day_advanced.disconnect(_on_day_advanced)
	if EventBus.npc_change_map.is_connected(_on_npc_change_map):
		EventBus.npc_change_map.disconnect(_on_npc_change_map)
	_map_host = null
	_transition_overlay = null
	_current_map = null
	_transitioning = false
	_map_npcs.clear()


func current_map() -> BaseMap:
	return _current_map if is_instance_valid(_current_map) else null


func current_map_id() -> StringName:
	return _current_map.map_id if is_instance_valid(_current_map) else &""


func is_transitioning() -> bool:
	return _transitioning


func request_map_change(map_id: StringName, spawn_id: StringName) -> Error:
	var validation := _validate_map_change(map_id, true)
	if validation != OK:
		return validation
	call_deferred("_change_map", map_id, spawn_id, true)
	return OK


func _validate_map_change(map_id: StringName, with_transition: bool) -> Error:
	if GameManager.player == null:
		return ERR_UNCONFIGURED
	if not MAP_SCENE_PATHS.has(map_id):
		return ERR_DOES_NOT_EXIST
	if with_transition:
		if _current_map == null:
			return ERR_UNCONFIGURED
		if _transitioning:
			return ERR_BUSY
		if map_id == current_map_id():
			return ERR_ALREADY_IN_USE
	return OK


func _configure_map(map: BaseMap, map_id: StringName, spawn_id: StringName) -> Error:
	if map == null or map.map_id != map_id:
		return ERR_INVALID_DATA
	var state: MapState = GameManager.map_states.get(map_id, null) as MapState
	if state == null:
		state = MapState.new()
		state.map_id = map_id
		GameManager.map_states[map_id] = state
	var error := map.from_state(state)
	if error != OK:
		push_error("[MapManager] map state load failed | map=%s error=%s" % [map_id, error_string(error)])
		return error
	var spawn := map.spawn_position(spawn_id)
	if not map.has_static_cell(map.world_to_cell(spawn)):
		push_error("[MapManager] invalid spawn | map=%s spawn=%s cell=%s" % [map_id, spawn_id, map.world_to_cell(spawn)])
		return ERR_INVALID_DATA
	return OK


func _apply_player_spawn(map: BaseMap, spawn_id: StringName) -> void:
	if map == null or GameManager.player == null:
		return
	var spawn := map.spawn_position(spawn_id)
	GameManager.player.global_position = spawn
	GameManager.player.position = spawn
	var world_bounds := Rect2(Vector2.ZERO, Vector2(map.get_map_size() * map.get_tile_size()))
	GameManager.player.set_camera_limits(Rect2i(world_bounds.position, world_bounds.size))


func _change_map(map_id: StringName = &"", spawn_id: StringName = &"", with_transition: bool = true) -> Error:
	var should_apply_spawn := spawn_id != &""
	if map_id == &"":
		map_id = current_map_id()
		if map_id == &"":
			map_id = DataCatalog.config.player_map_id
	if spawn_id == &"":
		spawn_id = GameManager.config.player_spawn_id
	var validation := _validate_map_change(map_id, with_transition)
	if validation != OK:
		return validation
	_transitioning = with_transition
	if is_instance_valid(_current_map) and _current_map.map_id == map_id:
		# Reusing the current map must preserve live cell flags/items (including
		# watering) instead of restoring the last serialized snapshot over them.
		GameManager.map_states[map_id] = _current_map.to_state()
		var same_error := OK
		if should_apply_spawn:
			_apply_player_spawn(_current_map, spawn_id)
		if with_transition:
			CalendarManager.resume(TRANSITION_LOCK)
			if is_instance_valid(GameManager.player):
				GameManager.player.unlock_input(TRANSITION_LOCK)
		_transitioning = false
		return same_error
	var path: String = str(MAP_SCENE_PATHS.get(map_id, ""))
	var next_map: BaseMap = null
	if not path.is_empty() and ResourceLoader.exists(path):
		var packed := load(path) as PackedScene
		if packed != null:
			next_map = packed.instantiate() as BaseMap
	var error: Error = OK
	if next_map == null:
		error = ERR_CANT_OPEN
	elif with_transition:
		error = GameManager.player.lock_input(TRANSITION_LOCK)
		if error == OK:
			error = CalendarManager.pause(TRANSITION_LOCK)
	if error != OK:
		if next_map != null:
			next_map.queue_free()
		if with_transition:
			CalendarManager.resume(TRANSITION_LOCK)
			if is_instance_valid(GameManager.player):
				GameManager.player.unlock_input(TRANSITION_LOCK)
			_transitioning = false
			EventBus.map_change_failed.emit(map_id, error)
		return error

	if with_transition:
		await _fade(1.0)
	_map_host.add_child(next_map)
	await get_tree().process_frame
	error = _configure_map(next_map, map_id, spawn_id)
	if error != OK:
		next_map.queue_free()
		if with_transition:
			await _fade(0.0)
			CalendarManager.resume(TRANSITION_LOCK)
			if is_instance_valid(GameManager.player):
				GameManager.player.unlock_input(TRANSITION_LOCK)
			_transitioning = false
			EventBus.map_change_failed.emit(map_id, error)
		return error

	var old_map := _current_map
	_unload_npcs(old_map)
	if old_map != null:
		GameManager.map_states[old_map.map_id] = old_map.to_state()
	_current_map = next_map
	if old_map != null:
		old_map.queue_free()
	if should_apply_spawn:
		_apply_player_spawn(next_map, spawn_id)
	_load_npcs(next_map)
	EventBus.map_changed.emit(map_id)
	if with_transition:
		await _fade(0.0)
		CalendarManager.resume(TRANSITION_LOCK)
		GameManager.player.unlock_input(TRANSITION_LOCK)
		_transitioning = false
	return OK


func _unload_npcs(map: BaseMap) -> void:
	if map == null:
		return
	for npc: FarmNpc in GameManager.npcs.values():
		if not is_instance_valid(npc) or npc.map != map:
			continue
		GameManager.npc_states[npc.state.npc_id] = npc.to_state()
		GameManager.npcs.erase(npc.state.npc_id)
		npc.queue_free()


func _load_npcs(map: BaseMap) -> void:
	if map == null:
		return
	var ids: Array = _map_npcs.get(map.map_id, [])
	if ids.is_empty():
		for state: NpcState in GameManager.npc_states.values():
			if state.map_id == map.map_id:
				ids.append(state.npc_id)
		_map_npcs[map.map_id] = ids
	var actor_host := GameManager.player.get_parent() as Node2D
	for npc_id: StringName in ids:
		var state := GameManager.npc_states.get(npc_id, null) as NpcState
		if state == null or state.map_id != map.map_id:
			continue
		var npc_scene := NPC_SCENES.get(npc_id, null) as PackedScene
		if npc_scene == null:
			continue
		var npc := npc_scene.instantiate() as FarmNpc
		if npc == null:
			continue
		actor_host.add_child(npc)
		if npc.from_state(state, map) != OK:
			npc.queue_free()
			continue
		npc.name = String(npc_id)
		GameManager.npcs[npc_id] = npc


func _fade(alpha: float) -> void:
	if _transition_overlay == null:
		return
	if _transition_overlay is Control and alpha > 0.0:
		(_transition_overlay as Control).mouse_filter = Control.MOUSE_FILTER_STOP
	if config.transition_duration <= 0.0:
		_transition_overlay.modulate.a = alpha
		if _transition_overlay is Control and alpha <= 0.0:
			(_transition_overlay as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	var tween := create_tween()
	tween.tween_property(_transition_overlay, "modulate:a", alpha, config.transition_duration)
	await tween.finished
	if _transition_overlay is Control and alpha <= 0.0:
		(_transition_overlay as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_day_advanced() -> void:
	await _change_map(&"farm", &"wake", false)


func _on_npc_change_map(npc_id: StringName, _from_map_id: StringName, to_map_id: StringName) -> void:
	for ids: Array in _map_npcs.values():
		ids.erase(npc_id)
	var ids: Array = _map_npcs.get(to_map_id, [])
	if not ids.has(npc_id):
		ids.append(npc_id)
	_map_npcs[to_map_id] = ids


func to_dict() -> Dictionary:
	return {"current_map_id": String(current_map_id())}


func from_dict(data: Dictionary) -> Error:
	if not SerializationUtil.has_valid_string(data, "current_map_id"):
		return ERR_INVALID_DATA
	return OK
