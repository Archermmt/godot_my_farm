extends ProjectTestCase

const RUNTIME_ROOT := "res://assets/art/runtime/tiny_farm/"

func test_purchased_crop_atlases_keep_native_dimensions() -> void:
	for file_name: String in ["parsnip_stages.png", "potato_stages.png", "pumpkin_stages.png"]:
		var image := Image.load_from_file(ProjectSettings.globalize_path(RUNTIME_ROOT + file_name))
		assert_true(image != null, "%s could not be loaded" % file_name)
		assert_equal(image.get_width(), 128, "%s width changed" % file_name)
		assert_equal(image.get_height(), 16, "%s height changed" % file_name)

func test_runtime_world_atlas_matches_logic_tile_grid() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(RUNTIME_ROOT + "world_tiles.png"))
	assert_true(image != null, "runtime world atlas could not be loaded")
	assert_equal(image.get_width(), 160)
	assert_equal(image.get_height(), 64)
	assert_true(FileAccess.file_exists(ProjectSettings.globalize_path("res://assets/art/external/tiny_farm_purchased/Documentation.txt")))

func test_runtime_character_atlas_matches_animation_contract() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(RUNTIME_ROOT + "player_atlas.png"))
	assert_true(image != null, "runtime character atlas could not be loaded")
	assert_equal(image.get_width(), 192)
	assert_equal(image.get_height(), 128)
