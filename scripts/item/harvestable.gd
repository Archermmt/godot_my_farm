class_name Harvestable
extends Item

var _hit_flash_tween: Tween = null


func _ready() -> void:
	super._ready()
	var obstacle := get_node_or_null("Obstacle") as StaticBody2D
	if obstacle != null:
		var collision := obstacle.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision != null:
			var typed_meta := meta as HarvestableMeta
			collision.disabled = not (typed_meta != null and typed_meta.blocks_movement)
	refresh_stage_visual()


func apply_tool(tool_kind: ToolMeta.ToolKind, damage: int = 0, commit: bool = true) -> ItemMeta.ItemFlag:
	var typed_state := state as HarvestableState
	var typed_meta := meta as HarvestableMeta
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
		refresh_stage_visual()
	_play_hit_flash()
	return ItemMeta.ItemFlag.AVAILABLE


func destroy() -> void:
	var flash_material := _visual_material()
	if flash_material == null:
		queue_free()
		return
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	var typed_meta := meta as HarvestableMeta
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


func active_drops() -> Dictionary[StringName, HarvestableDrop]:
	var stage := current_stage()
	# Once health reaches zero there is no regular stage match; drops belong to
	# the final configured stage and must still be resolved during depletion.
	if stage == null and is_depleted():
		var stages := stage_definitions()
		stage = stages.back() if not stages.is_empty() else null
	var drops: Dictionary[StringName, HarvestableDrop] = {}
	if stage != null:
		for drop: HarvestableDrop in stage.drops:
			if drop != null and drop.item_id != &"":
				drops[drop.item_id] = drop
	return drops


func health_stage() -> HarvestableStage:
	var typed_state := state as HarvestableState
	if typed_state == null:
		return null
	return _stage_for_health(typed_state.health, stage_definitions())


func stage_definitions() -> Array[HarvestableStage]:
	var typed_meta := meta as HarvestableMeta
	return typed_meta.stages if typed_meta != null else []


func stage_index() -> int:
	var selected := health_stage()
	var stages := stage_definitions()
	if selected == null:
		return -1
	for index: int in stages.size():
		if stages[index] == selected:
			return index
	return -1


func is_mature() -> bool:
	var stages := stage_definitions()
	return not stages.is_empty() and stage_index() == stages.size() - 1


func current_stage() -> HarvestableStage:
	var index := stage_index()
	var stages := stage_definitions()
	return stages[index] if index >= 0 else null


func _stage_for_health(current_health: int, stages: Array[HarvestableStage]) -> HarvestableStage:
	var selected: HarvestableStage = null
	for stage: HarvestableStage in stages:
		if stage == null or current_health < stage.min_health:
			continue
		if selected == null or stage.min_health > selected.min_health:
			selected = stage
	return selected


func refresh_stage_visual() -> void:
	var stage := health_stage()
	refresh_visual(stage.texture if stage != null else null, stage.visual_offset if stage != null else Vector2.ZERO)


func _play_hit_flash() -> Tween:
	var flash_material := _visual_material()
	if flash_material == null:
		return null
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	var typed_meta := meta as HarvestableMeta
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
