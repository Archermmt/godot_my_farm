class_name Harvestable
extends Item

var _hit_flash_tween: Tween = null


func _ready() -> void:
	super._ready()
	var obstacle := get_node_or_null("Obstacle") as StaticBody2D
	if obstacle != null:
		var collision := obstacle.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision != null:
			var typed_meta := get_meta() as HarvestableMeta
			collision.disabled = not (typed_meta != null and typed_meta.blocks_movement)
	refresh_health_visual()


func get_state() -> HarvestableState:
	return super.get_state() as HarvestableState


func get_meta() -> HarvestableMeta:
	return super.get_meta() as HarvestableMeta


func apply_tool(tool_kind: ToolMeta.ToolKind, damage: int = 0, commit: bool = true) -> ItemMeta.ItemFlag:
	var typed_state := get_state()
	var typed_meta := get_meta() as HarvestableMeta
	if typed_state == null or typed_meta == null:
		return ItemMeta.ItemFlag.INVALID
	if typed_state.health <= 0:
		return ItemMeta.ItemFlag.DEPLETED
	if self is Plant and not (self as Plant).is_mature():
		return ItemMeta.ItemFlag.NOT_MATURE
	if tool_kind != typed_meta.required_tool:
		return ItemMeta.ItemFlag.WRONG_TOOL
	if not commit or damage <= 0:
		return ItemMeta.ItemFlag.AVAILABLE
	typed_state.health = maxi(0, typed_state.health - maxi(1, damage))
	if not is_depleted():
		refresh_health_visual()
	_play_hit_flash()
	return ItemMeta.ItemFlag.AVAILABLE


func destroy() -> void:
	var flash_material := _visual_material()
	if flash_material == null:
		queue_free()
		return
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	var typed_meta := get_meta() as HarvestableMeta
	if typed_meta == null:
		queue_free()
		return
	flash_material.set_shader_parameter(&"flash_amount", 1.0)
	flash_material.set_shader_parameter(&"dissolve_amount", 0.0)
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_interval(typed_meta.depletion_white_duration)
	(
		_hit_flash_tween
		. tween_property(
			flash_material, "shader_parameter/dissolve_amount", 1.0, typed_meta.depletion_dissolve_duration
		)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	_hit_flash_tween.parallel().tween_property(
		flash_material, "shader_parameter/flash_amount", 0.35, typed_meta.depletion_dissolve_duration
	)
	_hit_flash_tween.tween_callback(Callable(self, "queue_free"))


func active_drops() -> Array[HarvestableDrop]:
	if self is Plant:
		var stage := (self as Plant).current_stage()
		if stage != null and not stage.drops.is_empty():
			return stage.drops
	var typed_meta := get_meta() as HarvestableMeta
	return typed_meta.drops if typed_meta != null else []


func health_stage() -> HarvestableStage:
	var typed_state := get_state()
	var typed_meta := get_meta() as HarvestableMeta
	if typed_state == null or typed_meta == null:
		return null
	var selected: HarvestableStage = null
	for stage: HarvestableStage in typed_meta.visual_stages:
		if stage == null or typed_state.health < stage.min_health:
			continue
		if selected == null or stage.min_health > selected.min_health:
			selected = stage
	return selected


func refresh_health_visual() -> void:
	if self is Plant:
		return
	var stage := health_stage()
	refresh_visual(stage.texture if stage != null else null, stage.visual_offset if stage != null else Vector2.ZERO)


func _play_hit_flash() -> Tween:
	var flash_material := _visual_material()
	if flash_material == null:
		return null
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	var typed_meta := get_meta() as HarvestableMeta
	if typed_meta == null:
		return null
	flash_material.set_shader_parameter(&"dissolve_amount", 0.0)
	flash_material.set_shader_parameter(&"flash_amount", 1.0)
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_interval(typed_meta.hit_flash_hold_duration)
	(
		_hit_flash_tween
		. tween_property(flash_material, "shader_parameter/flash_amount", 0.0, typed_meta.hit_flash_fade_duration)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	return _hit_flash_tween


func _visual_material() -> ShaderMaterial:
	if visual == null or not visual.material is ShaderMaterial:
		return null
	return visual.material as ShaderMaterial
