class_name Item
extends Node2D

var state: ItemState = null
var meta: ItemMeta = null
var pickup_area: Area2D = null
var trace_timer: Timer = null
var speed: float = 0.0
var _trace_ready := false
var _player_in_pickup_area := false
@onready var visual: Sprite2D = get_node_or_null("Visual") as Sprite2D

func _init() -> void:
	pass


func _ready() -> void:
	trace_timer = Timer.new()
	trace_timer.one_shot = true
	trace_timer.timeout.connect(_on_trace_timer_timeout)
	add_child(trace_timer)
	pickup_area = get_node_or_null("PickupArea") as Area2D
	if pickup_area != null:
		if not pickup_area.body_entered.is_connected(_on_pickup_area_body_entered):
			pickup_area.body_entered.connect(_on_pickup_area_body_entered)
		if not pickup_area.body_exited.is_connected(_on_pickup_area_body_exited):
			pickup_area.body_exited.connect(_on_pickup_area_body_exited)


func _exit_tree() -> void:
	ItemManager.unregister_pickup(self)
	if self is Harvestable:
		ItemManager.unregister_harvestable(self)


func from_state(next_state: ItemState) -> Error:
	if next_state == null or next_state.unique_id == &"" or next_state.meta_id == &"":
		return ERR_INVALID_PARAMETER
	var next_meta := DataCatalog.get_item(next_state.meta_id)
	if next_meta == null:
		return ERR_DOES_NOT_EXIST
	state = next_state
	meta = next_meta
	name = next_state.unique_id
	refresh_visual(meta.icon_texture, meta.visual_offset)
	return OK


func to_state() -> ItemState:
	if state == null:
		return null
	state.position = global_position
	return state


func item_id() -> StringName:
	return state.unique_id if state != null else &""


func is_depleted() -> bool:
	return state == null or state.health <= 0


func add_flag(flag: ItemMeta.ItemFlag) -> void:
	if state != null and flag not in state.flags:
		state.flags.append(flag)


func remove_flag(flag: ItemMeta.ItemFlag) -> void:
	if state != null:
		state.flags.erase(flag)


func has_flag(flag: ItemMeta.ItemFlag) -> bool:
	return state != null and flag in state.flags


func destroy() -> void:
	queue_free()


func set_trace_delay(delay_seconds: float) -> void:
	_trace_ready = false
	if trace_timer != null:
		trace_timer.stop()
	var delay := maxf(delay_seconds, 0.0)
	if delay <= 0.0:
		_trace_ready = true
	else:
		if trace_timer != null:
			trace_timer.wait_time = delay
			trace_timer.start()


func is_tracing_player() -> bool:
	return _trace_ready and _player_in_pickup_area


func move_toward_position(target_position: Vector2, delta: float) -> void:
	if delta <= 0.0 or speed <= 0.0:
		return
	global_position = global_position.move_toward(target_position, speed * delta)


func _draw() -> void:
	if meta != null and meta.can_pickup and meta.icon_texture == null:
		draw_circle(Vector2.ZERO, 6.0, Color("f6d365"))
		draw_circle(Vector2.ZERO, 6.0, Color("fff4b5"), false, 2.0)


func refresh_visual(texture: Texture2D, visual_position: Vector2) -> void:
	if visual == null:
		visual = get_node_or_null("Visual") as Sprite2D
	if visual != null:
		visual.texture = texture
		visual.position = visual_position
	queue_redraw()


func _visual_material() -> ShaderMaterial:
	if visual == null or not visual.material is ShaderMaterial:
		return null
	return visual.material as ShaderMaterial


func _on_pickup_area_body_entered(body: Node2D) -> void:
	if body != null and body.is_in_group("player"):
		_player_in_pickup_area = true
		ItemManager.register_pickup(self)


func _on_pickup_area_body_exited(body: Node2D) -> void:
	if body != null and body.is_in_group("player"):
		_player_in_pickup_area = false
		ItemManager.unregister_pickup(self)


func _on_trace_timer_timeout() -> void:
	_trace_ready = true
