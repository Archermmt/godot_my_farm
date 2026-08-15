class_name EffectManagerService
extends Node

@export var definitions: Array[EffectDefinition] = []

var _definitions: Dictionary[StringName, EffectDefinition] = {}
var _configuration_valid := false


func _ready() -> void:
	var errors := configure_definitions(definitions)
	for error: String in errors:
		push_error("[EffectManager] %s" % error)
	if not EventBus.request_tool_feedback.is_connected(_on_tool_feedback):
		EventBus.request_tool_feedback.connect(_on_tool_feedback)


func configure_definitions(entries: Array[EffectDefinition]) -> Array[String]:
	var errors: Array[String] = []
	_definitions.clear()
	for index: int in entries.size():
		var definition := entries[index]
		if definition == null:
			errors.append("definitions[%d] is null" % index)
			continue
		if definition.effect_id == &"":
			errors.append("definitions[%d] has empty effect_id" % index)
			continue
		if definition.scene == null:
			errors.append("definitions[%d] has no scene" % index)
			continue
		if definition.max_instances <= 0:
			errors.append("definitions[%d] max_instances must be positive" % index)
			continue
		if _definitions.has(definition.effect_id):
			errors.append("definitions contains duplicate effect_id %s" % definition.effect_id)
			continue
		_definitions[definition.effect_id] = definition
	_configuration_valid = errors.is_empty()
	return errors


func is_configured() -> bool:
	return _configuration_valid


func definition_count() -> int:
	return _definitions.size()


func play_action(
	effect_id: StringName,
	cells: Array[Vector2i],
	map: BaseMap = null,
	host: Node = null
) -> Node:
	var definition := _definitions.get(effect_id, null) as EffectDefinition
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
	var definition := _definitions.get(effect_id, null) as EffectDefinition
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


func _resolve_host(host: Node, map: BaseMap) -> Node:
	if host != null and is_instance_valid(host):
		return host
	if map != null and is_instance_valid(map):
		var map_effects := map.get_node_or_null("Effects")
		return map_effects if map_effects != null else map
	if is_instance_valid(SceneManager):
		var current_map := SceneManager.current_map()
		if current_map != null:
			var current_effects := current_map.get_node_or_null("Effects")
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
	play_action(event_id, cells, SceneManager.current_map())
