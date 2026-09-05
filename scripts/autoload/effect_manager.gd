class_name EffectManagerService
extends Node
var config: GameConfig:
	get: return DataCatalog.config

var _effect_host: Node = null
var _weather_effect: Node = null


func _ready() -> void:
	_effect_host = get_tree().current_scene.get_node_or_null("World/Effects")


func validate() -> Error:
	for effect_id: StringName in config.effect_scenes:
		var scene := config.effect_scenes[effect_id] as PackedScene
		if effect_id == &"" or scene == null:
			return ERR_INVALID_DATA
	return OK


func play_effect(effect_id: StringName, positions: Array[Vector2]) -> Node:
	var scene := config.effect_scenes.get(effect_id, null) as PackedScene
	if scene == null:
		return null
	if _effect_host == null:
		return null
	var effect := scene.instantiate() as Node
	if effect == null:
		return null
	if effect_id in [&"rain", &"storm", &"cloudy"] and is_instance_valid(_weather_effect):
		_weather_effect.queue_free()
		_weather_effect = null
	effect.set_meta("effect_id", effect_id)
	_effect_host.add_child(effect)
	if effect.has_method("play"):
		effect.call("play", effect_id, positions)
	if effect_id in [&"rain", &"storm", &"cloudy"]:
		_weather_effect = effect
	return effect

func stop_effect(effect_id: StringName) -> void:
	if is_instance_valid(_weather_effect) and _weather_effect.get_meta("effect_id", &"") == effect_id:
		_weather_effect.queue_free()
		_weather_effect = null
	if _effect_host == null:
		return
	for effect: Node in _effect_host.get_children():
		if effect.get_meta("effect_id", &"") != effect_id:
			continue
		if effect.has_method("stop"):
			effect.stop()
		else:
			effect.queue_free()
