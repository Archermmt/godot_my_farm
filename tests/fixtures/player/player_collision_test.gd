extends SceneTree

const FIXTURE_PATH := "res://tests/fixtures/player/movement_fixture.tscn"
const MAX_PLAYER_X := 594.1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture_scene: PackedScene = load(FIXTURE_PATH) as PackedScene
	if fixture_scene == null:
		push_error("[PlayerCollisionTest] fixture could not load")
		quit(1)
		return
	var fixture: Node = fixture_scene.instantiate()
	root.add_child(fixture)
	await process_frame
	await physics_frame
	var player: FarmPlayer = fixture.get_node("Player") as FarmPlayer
	if player == null:
		push_error("[PlayerCollisionTest] Player script did not load")
		fixture.queue_free()
		quit(1)
		return
	var start_x: float = player.global_position.x
	Input.action_press("move_right")
	for _frame: int in 150:
		await physics_frame
	Input.action_release("move_right")
	await physics_frame
	var final_x: float = player.global_position.x
	if final_x <= start_x or final_x > MAX_PLAYER_X:
		push_error("[PlayerCollisionTest] collision failed | start=%.2f final=%.2f max=%.2f" % [
			start_x,
			final_x,
			MAX_PLAYER_X,
		])
		fixture.queue_free()
		quit(1)
		return
	print("[PlayerCollisionTest] PASS | start_x=%.2f final_x=%.2f wall_limit=%.2f" % [
		start_x,
		final_x,
		MAX_PLAYER_X,
	])
	fixture.queue_free()
	await process_frame
	quit(0)
