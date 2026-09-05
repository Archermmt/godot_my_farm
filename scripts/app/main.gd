extends Node

@onready var player: FarmPlayer = $World/ActorHost/Player
@onready var status_dot: ColorRect = %StatusDot
@onready var status_label: Label = %StatusLabel
@onready var service_panel: ColorRect = %ServicePanel
@onready var service_summary: Label = %ServiceSummary
@onready var bootstrap_screen: Control = $UILayer/BootstrapScreen


func _ready() -> void:
	var catalog_errors := DataCatalog.validate()
	if not catalog_errors.is_empty():
		_show_boot_error(catalog_errors)
		return
	var calendar_errors := CalendarManager.validate()
	if not calendar_errors.is_empty():
		_show_boot_error(calendar_errors)
		return
	var effect_error := EffectManager.validate()
	if effect_error != OK:
		_show_boot_error(["EffectManager validation failed: %s" % error_string(effect_error)])
		return
	if not GameManager.is_initialized():
		_show_boot_error(["GameManager did not create a new game"])
		return
	var register_error: Error = MapManager.validate()
	if register_error != OK:
		_show_boot_error(["MapManager host registration failed: %s" % error_string(register_error)])
		return
	var player_error: Error = GameManager.register_player(player)
	if player_error != OK:
		_show_boot_error(["Player registration failed: %s" % error_string(player_error)])
		return
	if player.setup(GameManager.player_state()) != OK:
		_show_boot_error(["Player state binding failed"])
		return
	if player.backpack == null or player.backpack.backpack_state == null:
		_show_boot_error(["Player backpack binding failed"])
		return
	player.set_facing(player.state.facing)

	var map_error: Error = await MapManager.load_initial_map(GameManager.config.player_map_id, GameManager.config.player_spawn_id)
	if map_error != OK:
		_show_boot_error(["Initial map load failed: %s" % error_string(map_error)])
		return
	CalendarManager.start()
	bootstrap_screen.visible = false


func _show_boot_error(errors: Array[String]) -> void:
	CalendarManager.stop()
	status_dot.color = Color("e05a4f")
	status_label.text = "STARTUP BLOCKED"
	service_panel.color = Color(0.18, 0.045, 0.04, 0.94)
	var visible_errors: Array[String] = errors.slice(0, 4)
	service_summary.text = "APPLICATION ERROR\n%s" % "\n".join(visible_errors)
	push_error("[Main] startup blocked | %s" % " | ".join(errors))
