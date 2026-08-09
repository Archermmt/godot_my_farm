extends Node

const MAIN_PATH := "res://scenes/app/main.tscn"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var router: SceneManagerService = get_tree().root.get_node("SceneManager") as SceneManagerService
	var event_bus: EventBusService = get_tree().root.get_node("EventBus") as EventBusService
	var main := (load(MAIN_PATH) as PackedScene).instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	router.transition_duration = 0.0
	if router.current_map_id() != &"cabin" or get_tree().get_nodes_in_group("player").size() != 1:
		_fail("initial cabin/player contract failed")
		return
	var duplicate_result := router.request_map_change(&"farm", &"from_cabin")
	var busy_result := router.request_map_change(&"field", &"from_farm")
	if duplicate_result != OK or busy_result != ERR_BUSY:
		_fail("duplicate request contract failed | first=%s second=%s" % [error_string(duplicate_result), error_string(busy_result)])
		return
	await event_bus.map_changed
	await get_tree().process_frame
	if router.current_map_id() != &"farm" or get_tree().get_nodes_in_group("player").size() != 1:
		_fail("cabin -> farm contract failed")
		return
	var invalid_result := router.request_map_change(&"missing", &"default")
	if invalid_result != ERR_DOES_NOT_EXIST or router.current_map_id() != &"farm":
		_fail("invalid map must preserve current map")
		return
	var return_result := router.request_map_change(&"cabin", &"from_farm")
	if return_result != OK:
		_fail("farm -> cabin request failed")
		return
	await event_bus.map_changed
	await get_tree().process_frame
	var player_count: int = get_tree().get_nodes_in_group("player").size()
	if router.current_map_id() != &"cabin" or player_count != 1 or router.is_transitioning():
		_fail("farm -> cabin contract failed | map=%s players=%d transitioning=%s" % [router.current_map_id(), player_count, router.is_transitioning()])
		return
	print("[MapTransitionTest] PASS | cabin -> farm -> cabin | players=%d" % player_count)
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("[MapTransitionTest] %s" % message)
	get_tree().quit(1)
