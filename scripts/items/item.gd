class_name Item
extends Node2D

var state: ItemState = null
var meta: ItemMeta = null
@onready var visual: Sprite2D = get_node_or_null("Visual") as Sprite2D


func bind_state(item_state: ItemState, item_meta: ItemMeta) -> Error:
	if item_state == null or item_meta == null or item_state.instance_id == &"" or item_state.meta_id != item_meta.id:
		return ERR_INVALID_PARAMETER
	state = item_state
	meta = item_meta
	_refresh_visual()
	return OK


func item_id() -> StringName:
	return state.instance_id if state != null else &""


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
