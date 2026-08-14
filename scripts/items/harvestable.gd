class_name Harvestable
extends Item

@onready var harvestable_visual: Sprite2D = get_node_or_null("StageVisual") as Sprite2D


func _ready() -> void:
	_ensure_obstacle_collision()
	_refresh_health_visual()


func bind_state(item_state: ItemState, item_meta: ItemMeta) -> Error:
	if not item_state is HarvestableState or not item_meta is HarvestableMeta:
		return ERR_INVALID_PARAMETER
	var bind_error := super.bind_state(item_state, item_meta)
	if bind_error != OK:
		return bind_error
	_ensure_obstacle_collision()
	_refresh_health_visual()
	return OK


func harvestable_state() -> HarvestableState:
	return state as HarvestableState


func harvestable_meta() -> HarvestableMeta:
	return meta as HarvestableMeta


func tool_rejection_reason(tool_kind: ToolMeta.ToolKind) -> StringName:
	var typed_state := harvestable_state()
	var typed_meta := harvestable_meta()
	if typed_state == null or typed_meta == null or typed_state.health <= 0:
		return &"unavailable"
	if self is Plant and not (self as Plant).is_mature():
		return &"not_mature"
	if tool_kind != typed_meta.required_tool:
		return &"wrong_tool"
	return &""


func apply_tool(tool_kind: ToolMeta.ToolKind, damage: int) -> Error:
	if tool_rejection_reason(tool_kind) != &"":
		return ERR_UNAVAILABLE
	var typed_state := harvestable_state()
	typed_state.health = maxi(0, typed_state.health - maxi(1, damage))
	_refresh_health_visual()
	return OK


func is_depleted() -> bool:
	var typed_state := harvestable_state()
	return typed_state != null and typed_state.health <= 0


func active_drops() -> Array[HarvestableDrop]:
	if self is Plant:
		var stage := (self as Plant).current_stage()
		if stage != null and not stage.drops.is_empty():
			return stage.drops
	var typed_meta := harvestable_meta()
	return typed_meta.drops if typed_meta != null else []


func health_stage() -> HarvestableStage:
	var typed_state := harvestable_state()
	var typed_meta := harvestable_meta()
	if typed_state == null or typed_meta == null:
		return null
	var selected: HarvestableStage = null
	for stage: HarvestableStage in typed_meta.visual_stages:
		if stage == null or typed_state.health < stage.min_health:
			continue
		if selected == null or stage.min_health > selected.min_health:
			selected = stage
	return selected


func _refresh_health_visual() -> void:
	if self is Plant:
		return
	if harvestable_visual == null:
		harvestable_visual = get_node_or_null("StageVisual") as Sprite2D
	if harvestable_visual == null:
		return
	var stage := health_stage()
	harvestable_visual.texture = stage.texture if stage != null else null
	harvestable_visual.position = stage.visual_offset if stage != null else Vector2.ZERO


func _ensure_obstacle_collision() -> void:
	var typed_meta := harvestable_meta()
	if typed_meta == null or not typed_meta.blocks_movement or get_node_or_null("Obstacle") != null:
		return
	var obstacle := StaticBody2D.new()
	obstacle.name = "Obstacle"
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 11.0
	collision.shape = shape
	obstacle.add_child(collision)
	add_child(obstacle)
