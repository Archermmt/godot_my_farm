extends Node

@onready var map_host: Node2D = $World/MapHost
@onready var actor_host: Node2D = $World/ActorHost
@onready var player: FarmPlayer = $World/ActorHost/Player
@onready var ui_layer: CanvasLayer = $UILayer
@onready var transition_overlay: ColorRect = $UILayer/TransitionOverlay
@onready var status_dot: ColorRect = %StatusDot
@onready var status_label: Label = %StatusLabel
@onready var service_panel: ColorRect = %ServicePanel
@onready var service_summary: Label = %ServiceSummary
@onready var version_label: Label = %VersionLabel


func _ready() -> void:
	var version: Dictionary = Engine.get_version_info()
	var version_string: String = str(version.get("string", "unknown"))
	version_label.text = "Godot %s  |  GDScript" % version_string

	if not DataCatalog.is_ready_for_game():
		_show_boot_error(DataCatalog.validation_errors())
		return
	if not GameState.is_initialized():
		_show_boot_error(["GameState did not create a new game"])
		return
	var register_error: Error = SceneRouter.register_hosts(
		map_host,
		actor_host,
		ui_layer,
		transition_overlay
	)
	if register_error != OK:
		_show_boot_error(["SceneRouter host registration failed: %s" % error_string(register_error)])
		return
	var player_error: Error = _register_unique_player()
	if player_error != OK:
		_show_boot_error(["Player registration failed: %s" % error_string(player_error)])
		return
	player.set_facing(GameState.player.facing)

	TimeManager.start()
	status_dot.color = Color("77cc59")
	status_label.text = "T03  PLAYER READY"
	service_panel.visible = false
	player.set_camera_limits(Rect2i(0, 0, 640, 360))
	print("[T03] player ready | run=%.1f walk=%.1f facing=%s | %s | renderer=%s" % [
		player.run_speed,
		player.walk_speed,
		player.facing,
		DataCatalog.summary(),
		RenderingServer.get_current_rendering_method(),
	])


func _exit_tree() -> void:
	if SceneRouter != null:
		SceneRouter.unregister_hosts(map_host)


func _show_boot_error(errors: Array[String]) -> void:
	TimeManager.stop()
	status_dot.color = Color("e05a4f")
	status_label.text = "T02  STARTUP BLOCKED"
	service_panel.color = Color(0.18, 0.045, 0.04, 0.94)
	var visible_errors: Array[String] = errors.slice(0, 4)
	service_summary.text = "APPLICATION ERROR\n%s" % "\n".join(visible_errors)
	push_error("[Main] startup blocked | %s" % " | ".join(errors))


func _register_unique_player() -> Error:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() != 1 or players[0] != player:
		return ERR_ALREADY_EXISTS
	return SceneRouter.register_player(player)
