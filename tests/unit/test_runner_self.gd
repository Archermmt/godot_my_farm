extends ProjectTestCase


func test_runner_counts_assertions() -> void:
	assert_true(true)
	assert_equal(2 + 2, 4)

