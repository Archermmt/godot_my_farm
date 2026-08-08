extends SceneTree

const TEST_DIRECTORIES := [
	"res://tests/unit",
	"res://tests/integration",
]


func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	var test_files: Array[String] = []
	for directory: String in TEST_DIRECTORIES:
		_collect_test_files(directory, test_files)
	test_files.sort()

	if test_files.is_empty():
		push_error("[TestRunner] no test files discovered")
		quit(1)
		return

	var total_tests: int = 0
	var total_assertions: int = 0
	var all_failures: Array[String] = []

	for path: String in test_files:
		var test_script: Script = load(path) as Script
		if test_script == null:
			all_failures.append("%s could not be loaded" % path)
			continue
		var suite: ProjectTestCase = test_script.new() as ProjectTestCase
		if suite == null:
			all_failures.append("%s must extend ProjectTestCase" % path)
			continue
		var result: Dictionary = suite.run()
		total_tests += int(result.get("tests", 0))
		total_assertions += int(result.get("assertions", 0))
		var failures: Array = result.get("failures", []) as Array
		for failure: Variant in failures:
			all_failures.append("%s: %s" % [path, str(failure)])

	if total_tests == 0 or total_assertions == 0:
		all_failures.append("runner completed without tests or assertions")

	if not all_failures.is_empty():
		for failure: String in all_failures:
			push_error("[TestRunner] %s" % failure)
		print("[TestRunner] FAIL | %d tests | %d assertions | %d failures" % [
			total_tests,
			total_assertions,
			all_failures.size(),
		])
		quit(1)
		return

	print("[TestRunner] PASS | %d tests | %d assertions" % [total_tests, total_assertions])
	quit(0)


func _collect_test_files(directory_path: String, output: Array[String]) -> void:
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while not entry.is_empty():
		if not entry.begins_with("."):
			var path: String = directory_path.path_join(entry)
			if directory.current_is_dir():
				_collect_test_files(path, output)
			elif entry.begins_with("test_") and entry.ends_with(".gd"):
				output.append(path)
		entry = directory.get_next()
	directory.list_dir_end()

