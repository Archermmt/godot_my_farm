class_name Item
extends Node2D

var state: ItemState = null
var meta: ItemMeta = null
var collected := false
@onready var visual: Sprite2D = get_node_or_null("Visual") as Sprite2D

const ATTRACTION_RADIUS := 72.0
const COLLECT_RADIUS := 10.0
const ATTRACTION_SPEED := 180.0


func bind_state(item_state: ItemState, item_meta: ItemMeta) -> Error:
	if item_state == null or item_meta == null or item_state.instance_id == &"" or item_state.meta_id != item_meta.id:
		return ERR_INVALID_PARAMETER
	state = item_state
	meta = item_meta
	_refresh_visual()
	return OK


func item_id() -> StringName:
	return state.instance_id if state != null else &""


func attract_to(player: FarmPlayer, delta: float) -> bool:
	if player == null or player.state == null or meta == null or not meta.can_pickup:
		return false
	var offset := player.global_position - global_position
	var distance := offset.length()
	if distance > COLLECT_RADIUS and distance > 0.0:
		var speed_scale := 1.0 + clampf(1.0 - distance / ATTRACTION_RADIUS, 0.0, 1.0) * 2.0
		global_position += offset / distance * minf(distance, ATTRACTION_SPEED * speed_scale * maxf(delta, 0.0))
		return false
	if player.collect_item(meta, 1) <= 0:
		return false
	collected = true
	return true


func _draw() -> void:
	if meta != null and meta.can_pickup and meta.icon_texture == null:
		draw_circle(Vector2.ZERO, 6.0, Color("f6d365"))
		draw_circle(Vector2.ZERO, 6.0, Color("fff4b5"), false, 2.0)


func _refresh_visual() -> void:
	if visual == null:
		visual = get_node_or_null("Visual") as Sprite2D
	if visual != null and meta != null:
		visual.texture = meta.icon_texture
		visual.position = meta.visual_offset
	queue_redraw()
