class_name CellState
extends RefCounted

var cell: Vector2i = Vector2i.ZERO
var status: int = 0
var dug: bool = false
var watered_on_day: int = 0
var entities: Dictionary[StringName, EntityState] = {}


func is_watered(current_day: int) -> bool:
	return watered_on_day == current_day


func has_entities() -> bool:
	return not entities.is_empty()


func has_entity(entity_id: StringName) -> bool:
	return entities.has(entity_id)


func get_entity(entity_id: StringName) -> EntityState:
	return entities.get(entity_id, null) as EntityState


func add_entity(entity: EntityState) -> Error:
	if entity == null or entity.instance_id == &"" or entity.cell != cell:
		return ERR_INVALID_PARAMETER
	if entities.has(entity.instance_id):
		return ERR_ALREADY_EXISTS
	entities[entity.instance_id] = entity
	return OK


func remove_entity(entity_id: StringName) -> Error:
	if not entities.erase(entity_id):
		return ERR_DOES_NOT_EXIST
	return OK


func to_dict() -> Dictionary:
	var entity_data: Array[Dictionary] = []
	for entity_id: StringName in entities:
		entity_data.append(entities[entity_id].to_dict())
	return {
		"cell": SerializationUtil.vector2i_to_dict(cell),
		"status": status,
		"dug": dug,
		"watered_on_day": watered_on_day,
		"entities": entity_data,
	}


static func from_dict(data: Dictionary) -> CellState:
	if not SerializationUtil.has_valid_vector2i(data, "cell"):
		return null
	if not SerializationUtil.has_valid_bool(data, "dug"):
		return null
	if not SerializationUtil.has_valid_int(data, "status") or not SerializationUtil.has_valid_int(data, "watered_on_day"):
		return null
	if not SerializationUtil.has_valid_array(data, "entities"):
		return null
	if int(data.get("status", 0)) < 0 or int(data.get("watered_on_day", 0)) < 0:
		return null
	var restored := CellState.new()
	restored.cell = SerializationUtil.vector2i_from_dict(data.get("cell", {}) as Dictionary)
	restored.status = int(data.get("status", 0))
	restored.dug = bool(data.get("dug", false))
	restored.watered_on_day = int(data.get("watered_on_day", 0))
	for raw_entity: Variant in data.get("entities", []) as Array:
		if typeof(raw_entity) != TYPE_DICTIONARY:
			return null
		var entity := EntityState.from_dict(raw_entity as Dictionary)
		if entity == null or restored.add_entity(entity) != OK:
			return null
	return restored
