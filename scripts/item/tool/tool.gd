class_name Tool
extends Item

var charging := false
var charge_level := 0
var charge_elapsed := 0.0


func max_charge_level() -> int:
	var typed_meta := meta as ToolMeta
	return typed_meta.max_charge_level() if typed_meta != null else 0


func begin_charge() -> Error:
	if charging:
		return ERR_BUSY
	charging = true
	charge_level = 0
	charge_elapsed = 0.0
	return OK


func update_charge(delta: float) -> void:
	if charging:
		charge_elapsed += maxf(delta, 0.0)
		charge_level = mini(max_charge_level(), floori(charge_elapsed / 0.25))


func is_charging() -> bool:
	return charging


func charge_progress() -> float:
	if not charging:
		return 0.0
	var max_level := max_charge_level()
	return 1.0 if max_level <= 0 else clampf(charge_elapsed / (float(max_level) * 0.25), 0.0, 1.0)


func cancel_charge() -> void:
	charging = false
	charge_level = 0
	charge_elapsed = 0.0


func _can_use(map: BaseMap, available_energy: int) -> bool:
	var typed_meta := meta as ToolMeta
	return (
		map != null
		and typed_meta != null
		and (typed_meta.tool_kind != ToolMeta.ToolKind.NONE or meta is SeedMeta)
		and available_energy >= typed_meta.level_energy_cost(charge_level)
	)


func use(available_energy: int) -> ApplyResult:
	var result := ApplyResult.new()
	var map := MapManager.current_map()
	if not _can_use(map, available_energy):
		return result
	result = _use_impl()
	if result.succeeded():
		var typed_meta := meta as ToolMeta
		result.energy_spent = typed_meta.level_energy_cost(charge_level)
		var positions: Array[Vector2] = []
		for cell: Vector2i in result.cells:
			positions.append(map.cell_to_world(cell))
		EffectManager.play_tool_effect(typed_meta.event_id, positions)
		AudioManager.play_audio(typed_meta.event_id)
	return result


func _use_impl() -> ApplyResult:
	return ApplyResult.new()
