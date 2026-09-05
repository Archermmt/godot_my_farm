class_name TelevisionInteractable
extends InteractableItem


func interaction_prompt() -> String:
	return "Watch"


func interact(player: FarmPlayer) -> String:
	InteractManager.begin(dialogue_id, self, player)
	return ""
