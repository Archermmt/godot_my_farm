class_name PlayerState
extends Resource

var position: Vector2 = Vector2.ZERO
var facing: String = "down"
var max_health: int = 100
var health: int = 100
var max_energy: int = 100
var energy: int = 100
var gold: int = 500
var run_speed: float = 96.0
var walk_speed: float = 48.0
var pickup_radius: float = 72.0
var pickup_collect_distance: float = 10.0
var trace_delay: Dictionary[StringName, float] = {
	&"drop": 1.0,
	&"harvestable": 0.5,
	&"generate": 0.0,
}
var pickup_speed_curve: Curve = null
var indoor_camera_zoom: Vector2 = Vector2(1.5, 1.5)
var camera_zoom_duration: float = 0.3


func consume_energy(amount: int) -> bool:
	if amount < 0 or energy < amount:
		return false
	energy -= amount
	return true


func restore_for_new_day() -> void:
	health = max_health
	energy = max_energy


func to_dict() -> Dictionary:
	return {
		"position": SerializationUtil.vector2_to_dict(position),
		"facing": String(facing),
		"max_health": max_health,
		"health": health,
		"max_energy": max_energy,
		"energy": energy,
		"gold": gold,
	}


static func from_dict(data: Dictionary, template: PlayerState = null) -> PlayerState:
	var restored := template.duplicate(true) as PlayerState if template != null else PlayerState.new()
	for key: String in ["facing"]:
		if not SerializationUtil.has_valid_string(data, key):
			return null
	var max_energy_key := "max_energy" if data.has("max_energy") else "max_stamina"
	var energy_key := "energy" if data.has("energy") else "stamina"
	for key: String in ["max_health", "health", max_energy_key, energy_key, "gold"]:
		if not SerializationUtil.has_valid_int(data, key):
			return null
	if not SerializationUtil.has_valid_vector2(data, "position"):
		return null
	var restored_max_energy := int(data.get(max_energy_key, 100))
	var restored_energy := int(data.get(energy_key, restored_max_energy))
	if int(data.get("max_health", 100)) <= 0 or restored_max_energy <= 0:
		return null
	if int(data.get("health", 100)) < 0 or restored_energy < 0 or int(data.get("gold", 0)) < 0:
		return null
	if str(data.get("facing", "")) not in ["up", "down", "left", "right"]:
		return null
	restored.position = SerializationUtil.vector2_from_dict(data.get("position", {}) as Dictionary)
	restored.facing = str(data.get("facing", "down"))
	restored.max_health = int(data.get("max_health", 100))
	restored.health = mini(int(data.get("health", restored.max_health)), restored.max_health)
	restored.max_energy = restored_max_energy
	restored.energy = mini(restored_energy, restored.max_energy)
	restored.gold = int(data.get("gold", 0))
	return restored
