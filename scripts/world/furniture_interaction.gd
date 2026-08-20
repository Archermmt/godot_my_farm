class_name FurnitureInteraction
extends InteractionTarget

enum FurnitureKind { BED, TELEVISION, FIREPLACE }

@export var furniture_kind: FurnitureKind = FurnitureKind.FIREPLACE

func interaction_rejection_reason(_player_state: PlayerState) -> StringName:
	return &"" if furniture_kind != FurnitureKind.FIREPLACE else &"unavailable"

func interaction_prompt() -> String:
	match furniture_kind:
		FurnitureKind.BED: return "Sleep"
		FurnitureKind.TELEVISION: return "Watch"
		_: return "Interact"

func interact(_player: FarmPlayer):
	match furniture_kind:
		FurnitureKind.BED: return InteractionResultClass.sleep()
		FurnitureKind.TELEVISION: return InteractionResultClass.dialogue(&"television_report")
		_: return InteractionResultClass.none()
