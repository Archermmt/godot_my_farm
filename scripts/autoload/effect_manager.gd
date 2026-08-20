class_name EffectManagerService
extends Node

const DEFAULT_CONFIG_PATH := "res://data/game_config.tres"

var config: GameConfig = load(DEFAULT_CONFIG_PATH) as GameConfig

var _weather_effect: Node = null
var _active_weather_id: StringName = &""
var _definitions_valid := false
var _weather_scenes_valid := true
var _configuration_valid := false
var _player_interior := false


func _ready() -> void:
	var errors := _validate_definitions(config.effect_definitions)
	_definitions_valid = errors.is_empty()
	var weather_errors := _validate_weather_scenes(config.weather_effect_scenes)
	_weather_scenes_valid = weather_errors.is_empty()
	errors.append_array(weather_errors)
	_refresh_configuration_validity()
	for error: String in errors:
		push_error("[EffectManager] %s" % error)
	if not EventBus.request_tool_feedback.is_connected(_on_tool_feedback):
		EventBus.request_tool_feedback.connect(_on_tool_feedback)
	if not EventBus.weather_changed.is_connected(_on_weather_changed):
		EventBus.weather_changed.connect(_on_weather_changed)
	if not EventBus.map_changed.is_connected(_on_map_changed):
		EventBus.map_changed.connect(_on_map_changed)
	if not EventBus.player_interior_changed.is_connected(_on_player_interior_changed):
		EventBus.player_interior_changed.connect(_on_player_interior_changed)
	call_deferred("_refresh_weather_effect")


func configure_definitions(entries: Dictionary[StringName, EffectDefinition]) -> Array[String]:
	var errors := _validate_definitions(entries)
	var validated: Dictionary[StringName, EffectDefinition] = {}
	if errors.is_empty():
		config = config.duplicate() as GameConfig
		for effect_id: StringName in entries:
			var definition := entries[effect_id] as EffectDefinition
			validated[effect_id] = definition
	_definitions_valid = errors.is_empty()
	if _definitions_valid:
		config.effect_definitions = validated
	_refresh_configuration_validity()
	return errors


func configure_weather_scenes(entries: Dictionary[StringName, PackedScene]) -> Array[String]:
	var errors := _validate_weather_scenes(entries)
	var validated: Dictionary[StringName, PackedScene] = {}
	if errors.is_empty():
		config = config.duplicate() as GameConfig
		validated = entries.duplicate()
	_weather_scenes_valid = errors.is_empty()
	if _weather_scenes_valid:
		config.weather_effect_scenes = validated
	_refresh_configuration_validity()
	return errors


func is_configured() -> bool:
	return _configuration_valid


func definition_count() -> int:
	return config.effect_definitions.size()


func weather_scene_count() -> int:
	return config.weather_effect_scenes.size()


func play_action(
	effect_id: StringName,
	cells: Array[Vector2i],
	map: BaseMap = null,
	host: Node = null
) -> Node:
	var definition := config.effect_definitions.get(effect_id, null) as EffectDefinition
	if definition == null or definition.scene == null or cells.is_empty():
		return null
	var target_host := _resolve_host(host, map)
	if target_host == null:
		return null
	_trim_host(target_host, definition.max_instances)
	var effect := definition.scene.instantiate() as Node
	if effect == null:
		return null
	effect.set_meta("effect_id", effect_id)
	target_host.add_child(effect)
	if effect.has_method("configure"):
		effect.call("configure", effect_id, cells, map)
	return effect


func play(
	effect_id: StringName,
	host: Node,
	world_position: Vector2 = Vector2.ZERO
) -> Node:
	var definition := config.effect_definitions.get(effect_id, null) as EffectDefinition
	if definition == null or definition.scene == null or host == null:
		return null
	_trim_host(host, definition.max_instances)
	var effect := definition.scene.instantiate() as Node
	if effect == null:
		return null
	effect.set_meta("effect_id", effect_id)
	host.add_child(effect)
	if effect is Node2D:
		(effect as Node2D).global_position = world_position
	return effect


func refresh_weather(weather_id: StringName, map: BaseMap = null) -> Node:
	var current_map: BaseMap = map if map != null else MapManager.current_map()
	var scene: PackedScene = config.weather_effect_scenes.get(weather_id, null) as PackedScene
	if current_map == null or _player_interior or scene == null:
		_stop_weather_effect()
		return null
	var target_host: Node = _resolve_host(null, current_map)
	if (
		_weather_effect != null
		and is_instance_valid(_weather_effect)
		and _active_weather_id == weather_id
		and _weather_effect.get_parent() == target_host
	):
		return _weather_effect
	_stop_weather_effect()
	var effect: Node = scene.instantiate() as Node
	if effect == null or target_host == null:
		return null
	effect.set_meta("weather_effect_id", weather_id)
	target_host.add_child(effect)
	if effect.has_method("configure"):
		effect.call("configure", weather_id, current_map)
	_weather_effect = effect
	_active_weather_id = weather_id
	return effect


func _resolve_host(host: Node, map: BaseMap) -> Node:
	if host != null and is_instance_valid(host):
		return host
	if map != null and is_instance_valid(map):
		var map_effects: Node = map.get_node_or_null("Effects")
		return map_effects if map_effects != null else map
	if is_instance_valid(MapManager):
		var current_map: BaseMap = MapManager.current_map()
		if current_map != null:
			var current_effects: Node = current_map.get_node_or_null("Effects")
			return current_effects if current_effects != null else current_map
	return null


func _trim_host(host: Node, max_instances: int) -> void:
	var effects: Array[Node] = []
	for child: Node in host.get_children():
		if child.has_meta("effect_id"):
			effects.append(child)
	while effects.size() >= max_instances:
		var oldest: Node = effects.pop_front() as Node
		host.remove_child(oldest)
		oldest.queue_free()


func _on_tool_feedback(event_id: StringName, cells: Array[Vector2i]) -> void:
	play_action(event_id, cells, MapManager.current_map())


func _refresh_weather_effect() -> void:
	var weather_id: StringName = CalendarManager.current_weather_id() if is_instance_valid(CalendarManager) else &""
	refresh_weather(weather_id, MapManager.current_map())


func _stop_weather_effect() -> void:
	if _weather_effect != null and is_instance_valid(_weather_effect):
		_weather_effect.queue_free()
	_weather_effect = null
	_active_weather_id = &""


func _on_weather_changed(_weather_id: StringName, _previous_weather_id: StringName) -> void:
	_refresh_weather_effect()


func _on_map_changed(_map_id: StringName) -> void:
	_player_interior = false
	call_deferred("_refresh_weather_effect")


func _on_player_interior_changed(interior: bool) -> void:
	_player_interior = interior
	call_deferred("_refresh_weather_effect")


func _refresh_configuration_validity() -> void:
	_configuration_valid = _definitions_valid and _weather_scenes_valid


func _validate_definitions(entries: Dictionary[StringName, EffectDefinition]) -> Array[String]:
	var errors: Array[String] = []
	for effect_id: StringName in entries:
		var definition := entries[effect_id] as EffectDefinition
		if effect_id == &"":
			errors.append("definitions contains an empty effect id")
		elif definition == null:
			errors.append("definitions[%s] is null" % effect_id)
		elif definition.scene == null:
			errors.append("definitions[%s] has no scene" % effect_id)
		elif definition.max_instances <= 0:
			errors.append("definitions[%s] max_instances must be positive" % effect_id)
	return errors


func _validate_weather_scenes(entries: Dictionary[StringName, PackedScene]) -> Array[String]:
	var errors: Array[String] = []
	for weather_id: StringName in entries:
		var scene := entries[weather_id] as PackedScene
		if weather_id == &"":
			errors.append("weather_scenes contains an empty weather id")
		elif scene == null:
			errors.append("weather_scenes[%s] has no scene" % weather_id)
	return errors
