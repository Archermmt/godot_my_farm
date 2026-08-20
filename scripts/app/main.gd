extends Node

@onready var map_host: Node2D = $World/MapHost
@onready var actor_host: Node2D = $World/ActorHost
@onready var player: FarmPlayer = $World/ActorHost/Player
@onready var ui_layer: CanvasLayer = $UILayer
@onready var transition_overlay: ColorRect = $UILayer/TransitionOverlay
@onready var day_transition_overlay: ColorRect = $UILayer/DayTransitionOverlay
@onready var presentation_layer: PresentationController = $UILayer/PresentationLayer
@onready var status_dot: ColorRect = %StatusDot
@onready var status_label: Label = %StatusLabel
@onready var service_panel: ColorRect = %ServicePanel
@onready var service_summary: Label = %ServiceSummary
@onready var version_label: Label = %VersionLabel
@onready var bootstrap_screen: Control = $UILayer/BootstrapScreen
var _farm_pickups_spawned := false


func _ready() -> void:
	var version: Dictionary = Engine.get_version_info()
	var version_string: String = str(version.get("string", "unknown"))
	version_label.text = "Godot %s  |  GDScript" % version_string

	if not DataCatalog.is_ready_for_game():
		_show_boot_error(DataCatalog.validation_errors())
		return
	if not GameManager.is_initialized():
		_show_boot_error(["GameManager did not create a new game"])
		return
	var register_error: Error = MapManager.register_hosts(
		map_host,
		actor_host,
		ui_layer,
		transition_overlay,
		day_transition_overlay
	)
	if register_error != OK:
		_show_boot_error(["MapManager host registration failed: %s" % error_string(register_error)])
		return
	var player_error: Error = _register_unique_player()
	if player_error != OK:
		_show_boot_error(["Player registration failed: %s" % error_string(player_error)])
		return
	if player.bind_state(GameManager.player) != OK:
		_show_boot_error(["Player state binding failed"])
		return
	if not EventBus.map_changed.is_connected(_on_map_changed):
		EventBus.map_changed.connect(_on_map_changed)
	player.set_facing(player.state.facing)

	var map_error: Error = await MapManager.load_initial_map(GameManager.player.map_id, GameManager.player.spawn_id)
	if map_error != OK:
		_show_boot_error(["Initial map load failed: %s" % error_string(map_error)])
		return
	_on_map_changed(MapManager.current_map_id())
	GameManager.start()
	status_dot.color = Color("77cc59")
	status_label.text = "T13  NPC SCHEDULE READY"
	service_panel.visible = false
	bootstrap_screen.visible = false
	print("[T14] NPC schedule ready | map=%s player_count=%d npc_states=%d npc_actors=%d | run=%.1f walk=%.1f | %s | renderer=%s" % [
		MapManager.current_map_id(),
		get_tree().get_nodes_in_group("player").size(),
		GameManager.npcs.size(),
		MapManager.npc_actor_count(),
		player.run_speed,
		player.walk_speed,
		DataCatalog.summary(),
		RenderingServer.get_current_rendering_method(),
	])


func _exit_tree() -> void:
	if MapManager != null:
		MapManager.unregister_hosts(map_host)
	if AudioManager != null:
		AudioManager.shutdown()


func _on_map_changed(map_id: StringName) -> void:
	if map_id != &"farm" or _farm_pickups_spawned:
		return
	var farm := MapManager.current_map()
	if farm == null:
		return
	farm.spawn_pickup(&"wood", Vector2i(14, 12))
	farm.spawn_pickup(&"stone", Vector2i(15, 12))
	farm.spawn_pickup(&"wood", Vector2i(16, 12))
	_farm_pickups_spawned = true


func _show_boot_error(errors: Array[String]) -> void:
	GameManager.stop()
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
	return MapManager.register_player(player)
