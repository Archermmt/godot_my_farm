class_name ProjectTestCase
extends RefCounted

var _assertion_count: int = 0
var _test_count: int = 0
var _failures: Array[String] = []


func run() -> Dictionary:
	var test_methods: Array[StringName] = []
	var methods: Array[Dictionary] = get_method_list()
	for method: Dictionary in methods:
		var method_name := StringName(str(method.get("name", "")))
		if String(method_name).begins_with("test_"):
			test_methods.append(method_name)
	test_methods.sort()

	for method_name: StringName in test_methods:
		var assertions_before: int = _assertion_count
		_test_count += 1
		before_each()
		call(method_name)
		after_each()
		if _assertion_count == assertions_before:
			_failures.append("%s completed with zero assertions" % method_name)

	return {
		"tests": _test_count,
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func assert_true(value: bool, message: String = "Expected value to be true") -> void:
	_assertion_count += 1
	if not value:
		_failures.append(message)


func assert_equal(actual: Variant, expected: Variant, message: String = "") -> void:
	_assertion_count += 1
	if actual != expected:
		var detail: String = message
		if detail.is_empty():
			detail = "Expected %s, got %s" % [str(expected), str(actual)]
		_failures.append(detail)

