class_name BedInteractable
extends InteractableItem


func interaction_prompt() -> String:
	return "Sleep"


func interact(player: FarmPlayer) -> String:
	InteractManager.begin(
		&"bed_sleep_confirmation",
		self,
		player,
		func(choice: Dictionary) -> void:
			if str(choice.get("sleep", "")) == "yes":
				CalendarManager.advance_to_next_day()
	)
	return ""
