class_name Item
extends Node2D

var state: ItemState = null
var meta: ItemMeta = null
var pickup_area: Area2D = null
var trace_timer: Timer = null
var _player_in_pickup_area := false
var _tracing_player := false
@onready var visual: Sprite2D = get_node_or_null("Visual") as Sprite2D


func _init(item_state: ItemState = null) -> void:
	trace_timer = Timer.new()
	trace_timer.one_shot = true
	trace_timer.timeout.connect(_on_trace_timer_timeout)
	add_child(trace_timer)
	if item_state != null:
		var item_meta := DataCatalog.get_item(item_state.meta_id)
		if item_state.instance_id != &"" and item_meta != null:
			state = item_state
			meta = item_meta


func _ready() -> void:
	pickup_area = get_node_or_null("PickupArea") as Area2D
	if pickup_area != null:
		if not pickup_area.body_entered.is_connected(_on_pickup_area_body_entered):
			pickup_area.body_entered.connect(_on_pickup_area_body_entered)
		if not pickup_area.body_exited.is_connected(_on_pickup_area_body_exited):
			pickup_area.body_exited.connect(_on_pickup_area_body_exited)

func item_id() -> StringName:
	return state.instance_id if state != null else &""


func get_state() -> ItemState:
	return state


func get_meta() -> ItemMeta:
	return meta


func is_depleted() -> bool:
	return state == null or state.health <= 0


func destroy() -> void:
	queue_free()


func set_trace_delay(delay_seconds: float) -> void:
	_tracing_player = false
	trace_timer.stop()
	trace_timer.wait_time = maxf(delay_seconds, 0.0)
	if trace_timer.wait_time <= 0.0:
		_tracing_player = _player_in_pickup_area
	else:
		trace_timer.start()


func is_tracing_player() -> bool:
	return _tracing_player


func _draw() -> void:
	if meta != null and meta.can_pickup and meta.icon_texture == null:
		draw_circle(Vector2.ZERO, 6.0, Color("f6d365"))
		draw_circle(Vector2.ZERO, 6.0, Color("fff4b5"), false, 2.0)


func refresh_visual(texture: Texture2D, position: Vector2) -> void:
	if visual == null:
		visual = get_node_or_null("Visual") as Sprite2D
	if visual != null:
		visual.texture = texture
		visual.position = position
	queue_redraw()

func _on_pickup_area_body_entered(body: Node2D) -> void:
	if body != null and body.is_in_group("player"):
		_player_in_pickup_area = true
		if trace_timer == null or trace_timer.is_stopped():
			_tracing_player = true


func _on_pickup_area_body_exited(body: Node2D) -> void:
	if body != null and body.is_in_group("player"):
		_player_in_pickup_area = false
		_tracing_player = false


func _on_trace_timer_timeout() -> void:
	_tracing_player = _player_in_pickup_area
