class_name InteractableItem
extends Item

@export var dialogue_id: StringName = &""


func _ready() -> void:
	add_to_group("interaction_target")


func interaction_prompt() -> String:
	return "Interact"


func interact(_player: FarmPlayer) -> String:
	return "This is %s..." % _item_type_label()


func on_interact_area_entered(interact_area: InteractArea) -> void:
	var player := interact_area.get_parent() as FarmPlayer
	if player != null:
		InteractManager.show_prompt(self, player)


func on_interact_area_exited(_interact_area: InteractArea) -> void:
	InteractManager.hide_prompt(self)


func _item_type_label() -> String:
	if meta == null:
		return "Item"
	var key: String = String(ItemMeta.ItemType.keys()[meta.item_type])
	return String(key).capitalize()
