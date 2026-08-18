class_name InteractionTarget
extends Node2D

const InteractionResultClass = preload("res://scripts/interaction/interaction_result.gd")

@export var interaction_prompt_text: String = "Interact"
@export var dialogue_id: StringName = &""


func interaction_rejection_reason(_player_state: PlayerState) -> StringName:
	return &"" if not dialogue_id.is_empty() else &"unavailable"


func interaction_prompt() -> String:
	return interaction_prompt_text


func interact(_player: FarmPlayer):
	return InteractionResultClass.dialogue(dialogue_id) if not dialogue_id.is_empty() else InteractionResultClass.none()
