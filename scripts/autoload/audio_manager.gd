class_name AudioManagerService
extends Node

const DEFAULT_CONFIG_PATH := "res://data/game_config.tres"

var config: GameConfig = load(DEFAULT_CONFIG_PATH) as GameConfig

var _pools: Dictionary[StringName, Array] = {}
var _player_events: Dictionary[int, StringName] = {}
var _last_played_msec: Dictionary[StringName, int] = {}
var _ambient_event: StringName = &""
var _music_event: StringName = &""


func _ready() -> void:
	var definition_error := _validate_definitions(config.audio_definitions)
	if definition_error != OK:
		push_error("[AudioManager] invalid audio definitions: %s" % error_string(definition_error))
		return
	_apply_bus_volumes()
	if not EventBus.map_changed.is_connected(_on_map_changed):
		EventBus.map_changed.connect(_on_map_changed)


func _exit_tree() -> void:
	shutdown()


func shutdown() -> void:
	stop_all()
	for pool: Array in _pools.values():
		for player: AudioStreamPlayer in pool:
			player.stream = null
	_player_events.clear()


func configure_definitions(audio_definitions: Dictionary[StringName, AudioDefinition]) -> Error:
	stop_all()
	_last_played_msec.clear()
	var error := _validate_definitions(audio_definitions)
	if error != OK:
		return error
	config = config.duplicate() as GameConfig
	config.audio_definitions = audio_definitions.duplicate()
	return OK


func play_event(event_id: StringName) -> Error:
	var definition := config.audio_definitions.get(event_id, null) as AudioDefinition
	if definition == null:
		return ERR_UNCONFIGURED if config.audio_definitions.is_empty() else ERR_DOES_NOT_EXIST
	var now: int = Time.get_ticks_msec()
	var previous := int(_last_played_msec.get(event_id, -1000000))
	if definition.cooldown_msec > 0 and now - previous < definition.cooldown_msec:
		return ERR_BUSY
	if active_event_count(event_id) >= definition.max_instances:
		return ERR_BUSY
	var player := _available_player(definition.bus_name())
	if player == null:
		return ERR_OUT_OF_MEMORY
	_player_events[player.get_instance_id()] = event_id
	player.bus = definition.bus_name()
	player.stream = definition.stream if definition.stream != null else _placeholder_stream(definition)
	player.volume_db = definition.volume_db
	player.play()
	_last_played_msec[event_id] = now
	return OK


func stop_event(event_id: StringName) -> Error:
	var found := false
	for pool: Array in _pools.values():
		for player: AudioStreamPlayer in pool:
			if _player_events.get(player.get_instance_id(), &"") == event_id and player.playing:
				player.stop()
				found = true
	return OK if found else ERR_DOES_NOT_EXIST


func stop_all() -> void:
	for pool: Array in _pools.values():
		for player: AudioStreamPlayer in pool:
			player.stop()
	_ambient_event = &""
	_music_event = &""


func pool_size(channel: StringName = &"") -> int:
	if channel != &"":
		return (_pools.get(channel, []) as Array).size()
	var total := 0
	for pool: Array in _pools.values():
		total += pool.size()
	return total


func active_event_count(event_id: StringName) -> int:
	var count := 0
	for pool: Array in _pools.values():
		for player: AudioStreamPlayer in pool:
			if player.playing and _player_events.get(player.get_instance_id(), &"") == event_id:
				count += 1
	return count


func definition_count() -> int:
	return config.audio_definitions.size()


func current_loop_event(channel: StringName) -> StringName:
	if channel == &"Ambient":
		return _ambient_event
	if channel == &"Music":
		return _music_event
	return &""


func _available_player(bus_name: StringName) -> AudioStreamPlayer:
	var pool: Array = _pools.get(bus_name, []) as Array
	for player: AudioStreamPlayer in pool:
		if not player.playing:
			return player
	var limit := _pool_limit(bus_name)
	if pool.size() >= limit:
		return null
	var player := AudioStreamPlayer.new()
	player.bus = bus_name
	add_child(player)
	pool.append(player)
	_pools[bus_name] = pool
	return player


func _placeholder_stream(definition: AudioDefinition) -> AudioStreamWAV:
	const MIX_RATE := 22050
	var frame_count := maxi(1, roundi(definition.placeholder_duration * MIX_RATE))
	var data := PackedByteArray()
	data.resize(frame_count * 2)
	for frame: int in frame_count:
		var progress := float(frame) / float(frame_count)
		var envelope := 1.0 if definition.loop else pow(1.0 - progress, 2.0)
		var sample := clampi(roundi(sin(TAU * definition.placeholder_frequency * float(frame) / MIX_RATE) * envelope * 4096.0), -32768, 32767)
		data[frame * 2] = sample & 0xff
		data[frame * 2 + 1] = (sample >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	if definition.loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = frame_count
	return stream


func _on_map_changed(map_id: StringName) -> void:
	_ambient_event = _switch_loop_track(&"Ambient", _ambient_event, StringName("ambient_%s" % map_id))
	_music_event = _switch_loop_track(&"Music", _music_event, StringName("music_%s" % map_id))


func _switch_loop_track(channel: StringName, current_event: StringName, next_event: StringName) -> StringName:
	if next_event == current_event or not config.audio_definitions.has(next_event):
		return current_event
	var definition := config.audio_definitions[next_event] as AudioDefinition
	if definition.bus_name() != channel:
		return current_event
	if DisplayServer.get_name() == "headless":
		return next_event
	var previous_players: Array[AudioStreamPlayer] = []
	if current_event != &"":
		for player: AudioStreamPlayer in _pools.get(channel, []) as Array:
			if player.playing and _player_events.get(player.get_instance_id(), &"") == current_event:
				previous_players.append(player)
	if play_event(next_event) != OK:
		return current_event
	for player: AudioStreamPlayer in _pools.get(channel, []) as Array:
		if player.playing and _player_events.get(player.get_instance_id(), &"") == next_event:
			player.volume_db = config.crossfade_floor_db
			create_tween().tween_property(player, "volume_db", definition.volume_db, config.crossfade_duration)
	for player: AudioStreamPlayer in previous_players:
		var tween := create_tween()
		tween.tween_property(player, "volume_db", config.crossfade_floor_db, config.crossfade_duration)
		tween.finished.connect(player.stop)
	return next_event


func _apply_bus_volumes() -> void:
	_set_bus_volume(&"Master", config.master_volume_db)
	_set_bus_volume(&"Music", config.music_volume_db)
	_set_bus_volume(&"Ambient", config.ambient_volume_db)
	_set_bus_volume(&"SFX", config.sfx_volume_db)
	_set_bus_volume(&"UI", config.ui_volume_db)


func _set_bus_volume(bus_name: StringName, volume_db: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		push_error("[AudioManager] missing audio bus: %s" % bus_name)
		return
	AudioServer.set_bus_volume_db(bus_index, volume_db)


func _pool_limit(bus_name: StringName) -> int:
	match bus_name:
		&"Music":
			return config.music_pool_limit
		&"Ambient":
			return config.ambient_pool_limit
		&"SFX":
			return config.sfx_pool_limit
		&"UI":
			return config.ui_pool_limit
		_:
			return 1


func _validate_definitions(audio_definitions: Dictionary[StringName, AudioDefinition]) -> Error:
	for event_id: StringName in audio_definitions:
		if event_id == &"" or audio_definitions[event_id] == null:
			return ERR_INVALID_DATA
	return OK
