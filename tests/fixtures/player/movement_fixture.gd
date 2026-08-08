extends Node2D

const WORLD_RECT := Rect2i(0, 0, 960, 540)

@onready var player: FarmPlayer = $Player
@onready var state_label: Label = $HUD/StateLabel


func _ready() -> void:
	if player == null:
		push_error("[MovementFixture] Player script did not load")
		set_process(false)
		return
	var error: Error = player.set_camera_limits(WORLD_RECT)
	if error != OK:
		push_error("[MovementFixture] camera limits failed: %s" % error_string(error))


func _process(_delta: float) -> void:
	if player == null:
		return
	var state: Dictionary = player.debug_snapshot()
	var position_value: Vector2 = state["position"]
	state_label.text = "x=%d y=%d  %s  facing=%s  speed=%d" % [
		roundi(position_value.x),
		roundi(position_value.y),
		state["motion_state"],
		state["facing"],
		roundi((state["velocity"] as Vector2).length()),
	]
