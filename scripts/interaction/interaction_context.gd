class_name InteractionContext
extends RefCounted

var map_id: StringName
var player_cell: Vector2i
var facing: StringName
var charge_level: int
var stack_item_id: StringName
var stack_amount: int
var stamina: int
var map_revision: int


func _init(
	p_map_id: StringName,
	p_player_cell: Vector2i,
	p_facing: StringName,
	p_charge_level: int,
	p_stack_item_id: StringName,
	p_stack_amount: int,
	p_stamina: int,
	p_map_revision: int
) -> void:
	map_id = p_map_id
	player_cell = p_player_cell
	facing = p_facing
	charge_level = maxi(0, p_charge_level)
	stack_item_id = p_stack_item_id
	stack_amount = maxi(0, p_stack_amount)
	stamina = maxi(0, p_stamina)
	map_revision = p_map_revision
