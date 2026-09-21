class_name EffectManagerService
extends Node
var config: GameConfig:
	get:
		return DataCatalog.config

var _effect_host: Node = null
var _weather_effect: Node = null
const WEATHER_EFFECT_IDS := [&"clear", &"cloudy", &"rain", &"storm", &"snow"]


func _ready() -> void:
	var scene := get_tree().current_scene
	if scene != null:
		_effect_host = scene.get_node_or_null("World/Effects")


func setup() -> Error:
	for effect_id: StringName in config.effect_scenes:
		var scene := config.effect_scenes[effect_id] as PackedScene
		if effect_id == &"" or scene == null:
			return ERR_INVALID_DATA
	return OK


func _resolve_effect_host() -> Node:
	if is_instance_valid(_effect_host) and _effect_host.is_inside_tree():
		return _effect_host
	var scene := get_tree().current_scene
	_effect_host = scene.get_node_or_null("World/Effects") if scene != null else null
	return _effect_host


func play_weather_effect(weather_id: StringName, positions: Array[Vector2] = []) -> Node:
	if weather_id not in WEATHER_EFFECT_IDS:
		return null
	_stop_weather_effect()
	var scene := config.effect_scenes.get(weather_id, null) as PackedScene
	if scene == null:
		return null
	var effect_host := _resolve_effect_host()
	if effect_host == null:
		return null
	var effect := scene.instantiate() as Node
	if effect == null:
		return null
	effect.set_meta("effect_class", &"weather")
	effect.set_meta("effect_id", weather_id)
	effect_host.add_child(effect)
	if effect.has_method("play"):
		effect.call("play", weather_id, positions)
	_weather_effect = effect
	return effect


func play_tool_effect(effect_id: StringName, positions: Array[Vector2] = []) -> Node:
	var scene := config.effect_scenes.get(effect_id, null) as PackedScene
	if scene == null:
		return null
	var effect_host := _resolve_effect_host()
	if effect_host == null:
		return null
	var effect := scene.instantiate() as Node
	if effect == null:
		return null
	effect.set_meta("effect_class", &"tool")
	effect.set_meta("effect_id", effect_id)
	effect_host.add_child(effect)
	if effect.has_method("play"):
		effect.call("play", effect_id, positions)
	return effect


func play_effect(effect_id: StringName, positions: Array[Vector2]) -> Node:
	if effect_id in WEATHER_EFFECT_IDS:
		return play_weather_effect(effect_id, positions)
	return play_tool_effect(effect_id, positions)

func _stop_weather_effect() -> void:
	if not is_instance_valid(_weather_effect):
		_weather_effect = null
		return
	if _weather_effect.has_method("stop"):
		_weather_effect.stop()
	_weather_effect.queue_free()
	_weather_effect = null


func stop_effect(effect_id: StringName) -> void:
	if is_instance_valid(_weather_effect) and _weather_effect.get_meta("effect_id", &"") == effect_id:
		_weather_effect.queue_free()
		_weather_effect = null
	var effect_host := _resolve_effect_host()
	if effect_host == null:
		return
	for effect: Node in effect_host.get_children():
		if effect.get_meta("effect_id", &"") != effect_id:
			continue
		if effect.has_method("stop"):
			effect.stop()
		else:
			effect.queue_free()
