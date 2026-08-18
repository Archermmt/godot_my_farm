class_name ToolMeta
extends ItemMeta

enum ToolKind { NONE, HOE, WATERING_CAN, SICKLE, BASKET, PICKAXE, AXE }

@export var tool_kind: ToolKind = ToolKind.NONE
@export_range(0, 999, 1) var base_stamina_cost: int = 0
@export_range(1, 999, 1) var damage: int = 1
@export var charge_levels: Array[Vector2i] = [Vector2i.ONE, Vector2i(3, 1), Vector2i(3, 3), Vector2i(9, 3), Vector2i(9, 9)]
@export var damage_multipliers: Array[int] = [1]


func _init() -> void:
	item_type = ItemType.TOOL


func is_tool() -> bool:
	return true


func charges_damage() -> bool:
	return tool_kind in [ToolKind.PICKAXE, ToolKind.AXE]


func max_charge_level() -> int:
	return maxi(0, configured_level_count() - 1)


func configured_level_count() -> int:
	return damage_multipliers.size() if charges_damage() else charge_levels.size()


func effect_dimensions(charge_level: int) -> Vector2i:
	if charges_damage() or charge_levels.is_empty():
		return Vector2i.ONE
	var configured := charge_levels[clampi(charge_level, 0, charge_levels.size() - 1)]
	return Vector2i(maxi(1, configured.x), maxi(1, configured.y))


func damage_at_charge(charge_level: int) -> int:
	if not charges_damage() or damage_multipliers.is_empty():
		return damage
	var multiplier := damage_multipliers[clampi(charge_level, 0, damage_multipliers.size() - 1)]
	return damage * maxi(1, multiplier)
