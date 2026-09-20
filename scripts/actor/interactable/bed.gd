class_name BedInteractable
extends Interactable


func interact() -> void:
	begin_dialogue(&"bed_sleep_confirmation",
		func(choice: Dictionary) -> void:
			if str(choice.get("sleep", "")) == "yes":
				CalendarManager.next_day()
	)
