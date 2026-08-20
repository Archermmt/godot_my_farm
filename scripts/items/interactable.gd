class_name InteractableItem
extends Item

const InteractionResultClass = preload("res://scripts/interaction/interaction_result.gd")

enum Kind { BED, TELEVISION, FIREPLACE }

@export var kind: Kind = Kind.FIREPLACE
@export var interaction_prompt_text: String = "Interact"
@export var dialogue_id: StringName = &""


func _ready() -> void:
	add_to_group("interaction_target")


func on_effect_area_entered(effect_area: EffectArea) -> void:
	var player := effect_area.get_parent() as FarmPlayer
	var controller := get_tree().get_first_node_in_group("dialogue_controller")
	if player != null and interaction_rejection_reason(player.state) != &"":
		return
	if player != null and controller != null and controller.has_method("show_prompt"):
		controller.call("show_prompt", self, player)


func on_effect_area_exited(_effect_area: EffectArea) -> void:
	var controller := get_tree().get_first_node_in_group("dialogue_controller")
	if controller != null and controller.has_method("hide_prompt"):
		controller.call("hide_prompt", self)


func interaction_rejection_reason(_player_state: PlayerState) -> StringName:
	return &"unavailable" if kind == Kind.FIREPLACE else &""


func interaction_prompt() -> String:
	match kind:
		Kind.BED:
			return "Sleep"
		Kind.TELEVISION:
			return "Watch"
		_:
			return interaction_prompt_text


func interact(_player: FarmPlayer) -> InteractionResult:
	match kind:
		Kind.BED:
			return InteractionResultClass.sleep()
		Kind.TELEVISION:
			return InteractionResultClass.dialogue(dialogue_id)
		_:
			return InteractionResultClass.none()
