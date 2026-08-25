class_name InteractableItem
extends Item

@export var dialogue_id: StringName = &""


func _ready() -> void:
	add_to_group("interaction_target")


func interaction_prompt() -> String:
	return "Interact"


func interact(_player: FarmPlayer) -> String:
	return "This is %s..." % _item_type_label()


func on_effect_area_entered(effect_area: EffectArea) -> void:
	var player := effect_area.get_parent() as FarmPlayer
	if player != null:
		InteractManager.show_prompt(self, player)


func on_effect_area_exited(_effect_area: EffectArea) -> void:
	InteractManager.hide_prompt(self)


func _item_type_label() -> String:
	if meta == null:
		return "Item"
	var key: String = String(ItemMeta.ItemType.keys()[meta.item_type])
	return String(key).capitalize()
