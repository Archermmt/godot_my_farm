class_name InteractionResult
extends RefCounted

enum Kind { NONE, DIALOGUE, SLEEP }

var kind: Kind = Kind.NONE
var dialogue_id: StringName = &""
var prompt: String = ""


static func none() -> InteractionResult:
	return preload("res://scripts/interaction/interaction_result.gd").new()


static func dialogue(id: StringName) -> InteractionResult:
	var result = preload("res://scripts/interaction/interaction_result.gd").new()
	result.kind = Kind.DIALOGUE
	result.dialogue_id = id
	return result


static func sleep() -> InteractionResult:
	var result = preload("res://scripts/interaction/interaction_result.gd").new()
	result.kind = Kind.SLEEP
	return result
