class_name DialogueController
extends Node

enum SessionState { IDLE, REVEALING_TEXT, WAITING_INPUT, CHOOSING, CLOSING }
const DIALOGUE_LOCK := &"dialogue"
const TYPEWRITER_SPEED := 48.0

var session_state: SessionState = SessionState.IDLE
var current_definition: Resource = null
var current_line_index := 0
var reveal_characters := 0.0
var target: Node2D = null
var player: FarmPlayer = null
var _sleep_confirmation := false
var _bubble = null
var _prompt_bubble: DialogueBubble = null
var _prompt_target: Node2D = null
var _prompt_player: FarmPlayer = null


func _ready() -> void:
	add_to_group("dialogue_controller")


func is_active() -> bool:
	return session_state != SessionState.IDLE


func begin(dialogue_id: StringName, next_target: Node2D, next_player: FarmPlayer) -> Error:
	if is_active():
		return ERR_BUSY
	var definition := DataCatalog.get_dialogue(dialogue_id)
	if definition == null or definition.lines.is_empty() or next_player == null:
		return ERR_DOES_NOT_EXIST
	for line: Resource in definition.lines:
		if line == null or line.text.is_empty():
			return ERR_INVALID_DATA
	current_definition = definition
	target = next_target
	player = next_player
	hide_prompt(next_target)
	_sleep_confirmation = false
	return _open_session()


func begin_sleep(next_target: Node2D, next_player: FarmPlayer) -> Error:
	if is_active() or next_player == null:
		return ERR_BUSY if is_active() else ERR_INVALID_PARAMETER
	target = next_target
	player = next_player
	hide_prompt(next_target)
	_sleep_confirmation = true
	current_definition = preload("res://scripts/data/dialogue_definition.gd").new()
	var line := preload("res://scripts/data/dialogue_line.gd").new()
	line.speaker_name = "Bed"
	line.text = "Sleep until the next morning?"
	var lines: Array[Resource] = []
	lines.append(line)
	current_definition.lines = lines
	return _open_session()


func _open_session() -> Error:
	if player.lock_input(DIALOGUE_LOCK) != OK:
		return ERR_BUSY
	if GameManager.pause(DIALOGUE_LOCK) != OK:
		player.unlock_input(DIALOGUE_LOCK)
		return ERR_BUSY
	current_line_index = 0
	reveal_characters = 0.0
	session_state = SessionState.REVEALING_TEXT
	_bubble = preload("res://scenes/ui/dialogue_bubble.tscn").instantiate() as Control
	if _bubble == null:
		_close_session()
		return ERR_CANT_CREATE
	add_child(_bubble)
	_bubble.world_target = target
	_refresh_bubble()
	EventBus.dialogue_started.emit(current_definition.id if current_definition != null else &"")
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


func _process(delta: float) -> void:
	if session_state != SessionState.REVEALING_TEXT or current_definition == null:
		return
	var line: Resource = current_definition.lines[current_line_index]
	reveal_characters = minf(float(line.text.length()), reveal_characters + maxf(delta, 0.0) * TYPEWRITER_SPEED)
	if reveal_characters >= line.text.length():
		session_state = SessionState.WAITING_INPUT
	_refresh_bubble()


func _unhandled_input(event: InputEvent) -> void:
	if not is_active() or not event.is_pressed() or (event is InputEventKey and event.is_echo()):
		return
	if event.is_action_pressed("cancel"):
		_close_session()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("dialogue_advance") or event.is_action_pressed("ui_accept"):
		_advance()
		get_viewport().set_input_as_handled()


func _advance() -> void:
	if session_state == SessionState.REVEALING_TEXT:
		reveal_characters = float(current_definition.lines[current_line_index].text.length())
		session_state = SessionState.WAITING_INPUT
		_refresh_bubble()
		return
	if _sleep_confirmation:
		_close_session()
		GameManager.request_end_day()
		return
	if current_line_index + 1 >= current_definition.lines.size():
		_close_session()
		return
	current_line_index += 1
	reveal_characters = 0.0
	session_state = SessionState.REVEALING_TEXT
	_refresh_bubble()


func _refresh_bubble() -> void:
	if _bubble == null or current_definition == null:
		return
	var line: Resource = current_definition.lines[current_line_index]
	var visible_count := mini(line.text.length(), floori(reveal_characters))
	_bubble.set_content(line.speaker_name, line.text.substr(0, visible_count), session_state == SessionState.WAITING_INPUT, _sleep_confirmation)


func _close_session() -> void:
	if session_state == SessionState.IDLE:
		return
	session_state = SessionState.CLOSING
	if is_instance_valid(_bubble):
		_bubble.queue_free()
	_bubble = null
	if is_instance_valid(player):
		player.unlock_input(DIALOGUE_LOCK)
	GameManager.resume(DIALOGUE_LOCK)
	EventBus.dialogue_ended.emit()
	target = null
	player = null
	current_definition = null
	_sleep_confirmation = false
	current_line_index = 0
	reveal_characters = 0.0
	session_state = SessionState.IDLE
