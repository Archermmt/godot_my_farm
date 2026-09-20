extends ProjectTestCase


func test_toolbar_and_itembar_selection_are_type_safe() -> void:
	var backpack := GameManager.player.backpack
	assert_true(backpack.select_bar_index(PlayerBackpack.ActiveHandSource.TOOLBAR, 0))
	assert_true(backpack.active_item() is Tool)
	assert_true(backpack.select_bar_index(PlayerBackpack.ActiveHandSource.ITEMBAR, 0))
	assert_true(backpack.active_item() is Seed)


func test_invalid_switch_and_drop_do_not_mutate_snapshot() -> void:
	var backpack := GameManager.player.backpack
	assert_equal(backpack.switch_item(&"toolbar", -1, &"itembar", 0), ERR_INVALID_PARAMETER)
	var previous_source := backpack.active_hand_source
	backpack.active_hand_source = PlayerBackpack.ActiveHandSource.NONE
	var before := GameManager.snapshot()
	GameManager.player._drop_item()
	assert_equal(GameManager.snapshot(), before)
	backpack.active_hand_source = previous_source
