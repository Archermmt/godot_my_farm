class_name InteractManagerService
extends CanvasLayer

## Project-facing adapter around Dialogic. Targets only provide an id and a
## callback; timeline playback, input, layout and session cleanup stay here.
enum SessionState { IDLE, REVEALING_TEXT, WAITING_INPUT, CHOOSING, CLOSING }

const DIALOGUE_LOCK := &"dialogue"
const UI_THEME: Theme = preload("res://data/ui/game_theme.tres")

var session_state: SessionState = SessionState.IDLE
var current_definition: Resource = null # Kept as source-data compatibility for callers/tests.
var current_timeline: Resource = null
var target: Node2D = null
var player: FarmPlayer = null
var current_target: Node2D = null
var current_player: FarmPlayer = null
var _confirmation_callback := Callable()
var _prompt_bubble: DialogueBubble = null
var _prompt_target: Node2D = null
var _prompt_player: FarmPlayer = null
var _selected_choice: Dictionary = {}


func _ready() -> void:
	add_to_group("interact_manager")
	var dialogic := _dialogic()
	if dialogic != null and not dialogic.timeline_ended.is_connected(_on_dialogic_timeline_ended):
		dialogic.timeline_ended.connect(_on_dialogic_timeline_ended)
	if dialogic != null and dialogic.has_subsystem("Choices"):
		if not dialogic.Choices.choice_selected.is_connected(_on_dialogic_choice_selected):
			dialogic.Choices.choice_selected.connect(_on_dialogic_choice_selected)
		if not dialogic.Choices.question_shown.is_connected(_on_dialogic_question_shown):
			dialogic.Choices.question_shown.connect(_on_dialogic_question_shown)
		dialogic.Choices.use_input_action = true


func register_target(next_target: Node2D, next_player: FarmPlayer) -> void:
	if next_target == null or next_player == null or is_active():
		return
	current_target = next_target
	current_player = next_player


func unregister_target(next_target: Node2D) -> void:
	if current_target != next_target:
		return
	current_target = null
	current_player = null


func interact(next_player: FarmPlayer) -> void:
	if next_player == null or next_player != current_player or current_target == null:
		return
	current_target.interact(next_player)


func is_active() -> bool:
	return session_state != SessionState.IDLE


func begin(dialogue_id: StringName, next_target: Node2D, next_player: FarmPlayer, confirmation_callback: Callable = Callable()) -> Error:
	if is_active():
		return ERR_BUSY
	if next_player == null or dialogue_id == &"":
		return ERR_INVALID_PARAMETER
	var definition := DataCatalog.get_dialogue(dialogue_id)
	var timeline := _timeline_for_id(dialogue_id, definition)
	if timeline == null:
		return ERR_DOES_NOT_EXIST
	return begin_timeline(timeline, next_target, next_player, confirmation_callback, definition)


func begin_timeline(timeline: Resource, next_target: Node2D, next_player: FarmPlayer, confirmation_callback: Callable = Callable(), source_definition: Resource = null) -> Error:
	if is_active() or next_player == null:
		return ERR_BUSY if is_active() else ERR_INVALID_PARAMETER
	if timeline == null or not timeline.has_method("process"):
		return ERR_INVALID_DATA
	var dialogic := _dialogic()
	if dialogic == null:
		return ERR_UNCONFIGURED
	current_timeline = timeline
	current_definition = source_definition
	target = next_target
	player = next_player
	_confirmation_callback = confirmation_callback
	_selected_choice = {}
	hide_prompt(next_target)
	if player.lock_input(DIALOGUE_LOCK) != OK:
		_clear_session()
		return ERR_BUSY
	if GameManager.pause(DIALOGUE_LOCK) != OK:
		player.unlock_input(DIALOGUE_LOCK)
		_clear_session()
		return ERR_BUSY
	session_state = SessionState.REVEALING_TEXT
	dialogic.start(timeline)
	var started_id: StringName = source_definition.id if source_definition != null and "id" in source_definition else _dialogue_id(timeline)
	EventBus.dialogue_started.emit(started_id)
	return OK


func show_prompt(next_target: Node2D, next_player: FarmPlayer) -> Error:
	if is_active() or next_target == null or next_player == null:
		return ERR_BUSY if is_active() else ERR_INVALID_PARAMETER
	if _prompt_target == next_target and is_instance_valid(_prompt_bubble):
		return OK
	hide_prompt()
	_prompt_target = next_target
	_prompt_player = next_player
	_prompt_bubble = preload("res://scenes/ui/dialogue_bubble.tscn").instantiate() as DialogueBubble
	if _prompt_bubble == null:
		_prompt_target = null
		_prompt_player = null
		return ERR_CANT_CREATE
	add_child(_prompt_bubble)
	_prompt_bubble.theme = UI_THEME
	_prompt_bubble.world_target = next_target
	var prompt := "Interact"
	if next_target.has_method("interaction_prompt"):
		prompt = str(next_target.call("interaction_prompt"))
	_prompt_bubble.set_prompt(prompt)
	return OK


func hide_prompt(next_target: Node2D = null) -> void:
	if next_target != null and _prompt_target != next_target:
		return
	if is_instance_valid(_prompt_bubble):
		_prompt_bubble.queue_free()
	_prompt_bubble = null
	_prompt_target = null
	_prompt_player = null


func _unhandled_input(event: InputEvent) -> void:
	if not is_active() or not event.is_pressed() or (event is InputEventKey and event.is_echo()):
		return
	if event.is_action_pressed("cancel"):
		_close_session()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("dialogue_advance") or event.is_action_pressed("ui_accept"):
		var dialogic := _dialogic()
		if dialogic != null and dialogic.Inputs != null:
			dialogic.Inputs.handle_input()
		get_viewport().set_input_as_handled()


func _close_session() -> void:
	if session_state == SessionState.IDLE:
		return
	session_state = SessionState.CLOSING
	var dialogic := _dialogic()
	if dialogic != null and current_timeline != null and dialogic.current_timeline == current_timeline:
		dialogic.end_timeline(true)
	if is_instance_valid(player):
		player.unlock_input(DIALOGUE_LOCK)
	GameManager.resume(DIALOGUE_LOCK)
	EventBus.dialogue_ended.emit()
	_clear_session()


func _clear_session() -> void:
	target = null
	player = null
	current_timeline = null
	current_definition = null
	_confirmation_callback = Callable()
	_selected_choice = {}
	session_state = SessionState.IDLE


func _dialogic() -> Node:
	return get_node_or_null("/root/Dialogic")


func _dialogue_id(timeline: Resource) -> StringName:
	if timeline == null:
		return &""
	return StringName(timeline.resource_path.get_file().get_basename())


func _timeline_for_id(dialogue_id: StringName, definition: Resource) -> Resource:
	var path := "res://data/dialogue/%s.dtl" % String(dialogue_id)
	if ResourceLoader.exists(path):
		var loaded := load(path)
		if loaded != null:
			return loaded
	if definition == null or not "lines" in definition:
		return null
	return _timeline_from_definition(definition)


func _timeline_from_definition(definition: Resource) -> Resource:
	if definition == null or not "lines" in definition:
		return null
	var timeline := DialogicTimeline.new()
	var text_lines := PackedStringArray()
	for line: Resource in definition.lines:
		if line == null or line.text.is_empty():
			continue
		var speaker: String = line.speaker_name if not line.speaker_name.is_empty() else ""
		text_lines.append((speaker + ": " if not speaker.is_empty() else "") + line.text)
	timeline.from_text("\n".join(text_lines))
	return timeline


func _style_dialogic_choices() -> void:
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color(0.11, 0.16, 0.14, 0.98)
	focus_style.border_color = Color("f6d365")
	focus_style.set_border_width_all(3)
	focus_style.set_corner_radius_all(6)
	focus_style.set_expand_margin_all(2.0)
	focus_style.content_margin_left = 14.0
	focus_style.content_margin_right = 14.0
	focus_style.content_margin_top = 6.0
	focus_style.content_margin_bottom = 6.0

	for node: Node in get_tree().get_nodes_in_group("dialogic_choice_button"):
		if not node is Button or not (node as Button).visible:
			continue
		var button := node as Button
		button.add_theme_stylebox_override("focus", focus_style)
		button.add_theme_color_override("font_focus_color", Color("fff4c2"))
		button.pivot_offset = button.size * 0.5
		if not button.has_meta("farm_choice_focus_bound"):
			button.focus_entered.connect(_on_dialogue_choice_focus_entered.bind(button))
			button.focus_exited.connect(_on_dialogue_choice_focus_exited.bind(button))
			button.set_meta("farm_choice_focus_bound", true)
		_set_dialogue_choice_scale(button, button.has_focus())


func _set_dialogue_choice_scale(button: Button, focused: bool) -> void:
	if button == null:
		return
	button.pivot_offset = button.size * 0.5
	button.scale = Vector2.ONE * (1.08 if focused else 1.0)


func _on_dialogue_choice_focus_entered(button: Button) -> void:
	_set_dialogue_choice_scale(button, true)


func _on_dialogue_choice_focus_exited(button: Button) -> void:
	_set_dialogue_choice_scale(button, false)


## Dialogic signal handlers are kept together after lifecycle and service code.
func _on_dialogic_timeline_ended() -> void:
	if not is_active() or session_state == SessionState.CLOSING:
		return
	var callback := _confirmation_callback
	var selected_choice := _selected_choice.duplicate()
	current_timeline = null
	_close_session()
	if callback.is_valid():
		callback.call(selected_choice)


func _on_dialogic_choice_selected(choice_info: Dictionary) -> void:
	if is_active():
		_selected_choice = choice_info.duplicate()


func _on_dialogic_question_shown(_question_info: Dictionary) -> void:
	if is_active():
		session_state = SessionState.CHOOSING
		_style_dialogic_choices()
