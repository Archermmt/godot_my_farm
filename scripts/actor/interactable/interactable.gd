class_name Interactable
extends Node2D

@export var dialogue_id: StringName = &""

const DIALOGUE_LOCK := &"dialogue"
const UI_THEME: Theme = preload("res://data/ui/game_theme.tres")
var _prompt_bubble: DialogueBubble = null
var _dialogue_player: FarmPlayer = null
var _dialogue_callback := Callable()
@onready var interaction_marker: Marker2D = get_node_or_null("InteractionMarker") as Marker2D
@onready var interaction_area: Area2D = get_node_or_null("InteractionArea") as Area2D


func _ready() -> void:
	add_to_group("interaction_target")
	if interaction_area != null:
		interaction_area.monitoring = true
		interaction_area.monitorable = true


func interaction_name() -> String:
	return String(name).capitalize()


func interact() -> void:
	pass


func begin_dialogue(
	next_dialogue_id: StringName = dialogue_id, on_completed: Callable = Callable()
) -> Error:
	var player := GameManager.player
	if player == null or next_dialogue_id == &"" or Dialogic.current_timeline != null:
		return ERR_INVALID_PARAMETER
	var timeline_path := "res://data/dialogue/%s.dtl" % String(next_dialogue_id)
	if not ResourceLoader.exists(timeline_path):
		return ERR_DOES_NOT_EXIST
	var timeline := load(timeline_path)
	if timeline == null:
		return ERR_INVALID_DATA
	if player.lock_input(DIALOGUE_LOCK) != OK or CalendarManager.pause(DIALOGUE_LOCK) != OK:
		player.unlock_input(&"dialogue")
		return ERR_BUSY
	hide_bubble()
	_dialogue_player = player
	_dialogue_callback = on_completed
	if not Dialogic.timeline_ended.is_connected(_on_dialogue_ended):
		Dialogic.timeline_ended.connect(_on_dialogue_ended)
	if Dialogic.has_subsystem("Choices") and not Dialogic.Choices.choice_selected.is_connected(_on_dialogue_choice):
		Dialogic.Choices.choice_selected.connect(_on_dialogue_choice)
	Dialogic.start(timeline)
	return OK


func _on_dialogue_choice(choice: Dictionary) -> void:
	if Dialogic.current_timeline != null:
		_dialogue_callback = _dialogue_callback.bind(choice)


func _on_dialogue_ended() -> void:
	if _dialogue_player == null:
		return
	var player := _dialogue_player
	var callback := _dialogue_callback
	_dialogue_player = null
	_dialogue_callback = Callable()
	if is_instance_valid(player):
		player.unlock_input(DIALOGUE_LOCK)
	CalendarManager.resume(DIALOGUE_LOCK)
	if callback.is_valid():
		callback.call()


func show_bubble() -> void:
	hide_bubble()
	_prompt_bubble = preload("res://scenes/ui/dialogue_bubble.tscn").instantiate() as DialogueBubble
	if _prompt_bubble == null or interaction_marker == null:
		if is_instance_valid(_prompt_bubble):
			_prompt_bubble.queue_free()
		_prompt_bubble = null
		return
	interaction_marker.add_child(_prompt_bubble)
	_prompt_bubble.z_index = 100
	_prompt_bubble.theme = UI_THEME
	_prompt_bubble.set_prompt(interaction_name())


func hide_bubble() -> void:
	if is_instance_valid(_prompt_bubble):
		_prompt_bubble.queue_free()
	_prompt_bubble = null
