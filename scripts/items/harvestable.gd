class_name Harvestable
extends Item

const HIT_FLASH_HOLD_DURATION := 0.04
const HIT_FLASH_FADE_DURATION := 0.12
const DEPLETION_WHITE_DURATION := 0.08
const DEPLETION_DISSOLVE_DURATION := 0.38

@onready var harvestable_visual: Sprite2D = get_node_or_null("StageVisual") as Sprite2D
var _hit_flash_tween: Tween = null


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
	if not is_depleted():
		_refresh_health_visual()
	_play_hit_flash()
	return OK


func is_depleted() -> bool:
	var typed_state := harvestable_state()
	return typed_state != null and typed_state.health <= 0


func play_depletion_flash_then_free() -> void:
	var flash_material := _visual_material()
	if flash_material == null:
		queue_free()
		return
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	flash_material.set_shader_parameter(&"flash_amount", 1.0)
	flash_material.set_shader_parameter(&"dissolve_amount", 0.0)
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_interval(DEPLETION_WHITE_DURATION)
	_hit_flash_tween.tween_property(
		flash_material,
		"shader_parameter/dissolve_amount",
		1.0,
		DEPLETION_DISSOLVE_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_hit_flash_tween.parallel().tween_property(
		flash_material,
		"shader_parameter/flash_amount",
		0.35,
		DEPLETION_DISSOLVE_DURATION
	)
	_hit_flash_tween.tween_callback(Callable(self, "queue_free"))


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


func _play_hit_flash() -> Tween:
	var flash_material := _visual_material()
	if flash_material == null:
		return null
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	flash_material.set_shader_parameter(&"dissolve_amount", 0.0)
	flash_material.set_shader_parameter(&"flash_amount", 1.0)
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_interval(HIT_FLASH_HOLD_DURATION)
	_hit_flash_tween.tween_property(
		flash_material,
		"shader_parameter/flash_amount",
		0.0,
		HIT_FLASH_FADE_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return _hit_flash_tween


func _visual_material() -> ShaderMaterial:
	if harvestable_visual == null:
		harvestable_visual = get_node_or_null("StageVisual") as Sprite2D
	if harvestable_visual == null or not harvestable_visual.material is ShaderMaterial:
		return null
	return harvestable_visual.material as ShaderMaterial


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
