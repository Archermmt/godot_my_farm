class_name SerializationUtil
extends RefCounted


static func vector2i_to_dict(value: Vector2i) -> Dictionary:
	return {"x": value.x, "y": value.y}


static func vector2_to_dict(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}


static func vector2i_from_dict(data: Dictionary, default_value: Vector2i = Vector2i.ZERO) -> Vector2i:
	var x_value: Variant = data.get("x", default_value.x)
	var y_value: Variant = data.get("y", default_value.y)
	return Vector2i(int(x_value), int(y_value))


static func vector2_from_dict(data: Dictionary, default_value: Vector2 = Vector2.ZERO) -> Vector2:
	var x_value: Variant = data.get("x", default_value.x)
	var y_value: Variant = data.get("y", default_value.y)
	return Vector2(float(x_value), float(y_value))


static func has_valid_vector2i(data: Dictionary, key: String) -> bool:
	if not data.has(key):
		return true
	if typeof(data[key]) != TYPE_DICTIONARY:
		return false
	var vector_data: Dictionary = data[key] as Dictionary
	return _is_integer_value(vector_data.get("x", 0)) and _is_integer_value(vector_data.get("y", 0))


static func has_valid_vector2(data: Dictionary, key: String) -> bool:
	if not data.has(key):
		return true
	if typeof(data[key]) != TYPE_DICTIONARY:
		return false
	var vector_data: Dictionary = data[key] as Dictionary
	return _is_number(vector_data.get("x", 0)) and _is_number(vector_data.get("y", 0))


static func has_valid_string(data: Dictionary, key: String) -> bool:
	if not data.has(key):
		return true
	return typeof(data[key]) == TYPE_STRING or typeof(data[key]) == TYPE_STRING_NAME


static func has_valid_int(data: Dictionary, key: String) -> bool:
	if not data.has(key):
		return true
	return _is_integer_value(data[key])


static func has_valid_bool(data: Dictionary, key: String) -> bool:
	if not data.has(key):
		return true
	return typeof(data[key]) == TYPE_BOOL


static func has_valid_array(data: Dictionary, key: String) -> bool:
	if not data.has(key):
		return true
	return typeof(data[key]) == TYPE_ARRAY


static func has_valid_dictionary(data: Dictionary, key: String) -> bool:
	if not data.has(key):
		return true
	return typeof(data[key]) == TYPE_DICTIONARY


static func string_name_array_to_strings(values: Array[StringName]) -> Array[String]:
	var output: Array[String] = []
	for value: StringName in values:
		output.append(String(value))
	return output


static func string_array_to_string_names(values: Array) -> Array[StringName]:
	var output: Array[StringName] = []
	for value: Variant in values:
		output.append(StringName(str(value)))
	return output


static func is_string_array(values: Array) -> bool:
	for value: Variant in values:
		if typeof(value) != TYPE_STRING and typeof(value) != TYPE_STRING_NAME:
			return false
	return true


static func _is_integer_value(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		return is_equal_approx(float(value), floor(float(value)))
	return false


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
