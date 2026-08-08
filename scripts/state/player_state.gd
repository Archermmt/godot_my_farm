class_name PlayerState
extends RefCounted

var map_id: StringName = &"farm"
var spawn_id: StringName = &"default"
var cell: Vector2i = Vector2i.ZERO
var facing: StringName = &"down"
var max_health: int = 100
var health: int = 100
var max_stamina: int = 100
var stamina: int = 100
var gold: int = 0


func set_health(value: int) -> void:
	health = clampi(value, 0, max(1, max_health))


func set_stamina(value: int) -> void:
	stamina = clampi(value, 0, max(1, max_stamina))


func set_gold(value: int) -> void:
	gold = max(0, value)


func set_max_health(value: int) -> void:
	max_health = max(1, value)
	set_health(health)


func set_max_stamina(value: int) -> void:
	max_stamina = max(1, value)
	set_stamina(stamina)


func to_dict() -> Dictionary:
	return {
		"map_id": String(map_id),
		"spawn_id": String(spawn_id),
		"cell": SerializationUtil.vector2i_to_dict(cell),
		"facing": String(facing),
		"max_health": max_health,
		"health": health,
		"max_stamina": max_stamina,
		"stamina": stamina,
		"gold": gold,
	}


static func from_dict(data: Dictionary) -> PlayerState:
	for key: String in ["map_id", "spawn_id", "facing"]:
		if not SerializationUtil.has_valid_string(data, key):
			return null
	for key: String in ["max_health", "health", "max_stamina", "stamina", "gold"]:
		if not SerializationUtil.has_valid_int(data, key):
			return null
	if not SerializationUtil.has_valid_vector2i(data, "cell"):
		return null
	if int(data.get("max_health", 100)) <= 0 or int(data.get("max_stamina", 100)) <= 0:
		return null
	if int(data.get("health", 100)) < 0 or int(data.get("stamina", 100)) < 0 or int(data.get("gold", 0)) < 0:
		return null
	var restored := PlayerState.new()
	restored.map_id = StringName(str(data.get("map_id", "farm")))
	restored.spawn_id = StringName(str(data.get("spawn_id", "default")))
	restored.cell = SerializationUtil.vector2i_from_dict(data.get("cell", {}) as Dictionary)
	restored.facing = StringName(str(data.get("facing", "down")))
	restored.set_max_health(int(data.get("max_health", 100)))
	restored.set_health(int(data.get("health", restored.max_health)))
	restored.set_max_stamina(int(data.get("max_stamina", 100)))
	restored.set_stamina(int(data.get("stamina", restored.max_stamina)))
	restored.set_gold(int(data.get("gold", 0)))
	return restored
