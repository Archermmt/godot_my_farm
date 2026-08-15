class_name GameStatusPanel
extends Control

@onready var calendar_label: Label = $Panel/Calendar
@onready var player_label: Label = $Panel/Player
@onready var hand_label: Label = $Panel/Hand

var _last_snapshot := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not EventBus.time_advanced.is_connected(_on_state_changed):
		EventBus.time_advanced.connect(_on_state_changed)
	if not EventBus.day_advanced.is_connected(_on_day_advanced):
		EventBus.day_advanced.connect(_on_day_advanced)
	if not EventBus.weather_changed.is_connected(_on_weather_changed):
		EventBus.weather_changed.connect(_on_weather_changed)
	if not EventBus.player_state_changed.is_connected(_on_state_changed):
		EventBus.player_state_changed.connect(_on_state_changed)
	if not EventBus.active_hand_changed.is_connected(_on_state_changed):
		EventBus.active_hand_changed.connect(_on_state_changed)
	if not EventBus.bar_selection_changed.is_connected(_on_state_changed):
		EventBus.bar_selection_changed.connect(_on_state_changed)
	_refresh()


func _on_state_changed(_value = null, _before = {}, _delta = 0) -> void:
	_refresh()


func _on_day_advanced(_previous_day: int, _current_day: int) -> void:
	_refresh()


func _on_weather_changed(_weather_id: StringName, _previous_weather_id: StringName) -> void:
	_refresh()


func _refresh() -> void:
	if not is_instance_valid(GameManager) or not GameManager.is_initialized():
		return
	var calendar: CalendarState = GameManager.calendar
	var player: PlayerState = GameManager.player
	if calendar == null or player == null:
		return
	var active_stack := player.active_stack()
	var weather_id := WeatherManager.current_weather_id() if is_instance_valid(WeatherManager) else &""
	var snapshot := "%d/%d/%d/%d/%d/%d/%s|%d/%d/%d/%d/%d|%d/%s/%d" % [
		calendar.year, calendar.month, calendar.day, calendar.weekday, calendar.hour, calendar.minute,
		weather_id,
		player.health, player.max_health, player.stamina, player.max_stamina, player.gold,
		player.active_hand_source, active_stack.item_id if active_stack != null else &"", active_stack.amount if active_stack != null else 0,
	]
	if snapshot == _last_snapshot:
		return
	_last_snapshot = snapshot
	calendar_label.text = "Y%d M%d D%d W%d %02d:%02d\n%s / %s" % [
		calendar.year, calendar.month, calendar.day, calendar.weekday, calendar.hour, calendar.minute,
		String(calendar.season()).left(3).to_upper(), String(weather_id).to_upper(),
	]
	player_label.text = "HP %d/%d  EN %d/%d  G %d" % [
		player.health, player.max_health, player.stamina, player.max_stamina, player.gold,
	]
	var source_name := "EMPTY"
	match player.active_hand_source:
		PlayerState.ActiveHandSource.TOOLBAR:
			source_name = "TOOLS"
		PlayerState.ActiveHandSource.ITEMBAR:
			source_name = "ITEMS"
	if active_stack == null or active_stack.is_empty():
		hand_label.text = "HAND  %s  |  EMPTY" % source_name
	else:
		var meta := DataCatalog.get_item(active_stack.item_id)
		var display_name := meta.display_name if meta != null else String(active_stack.item_id)
		var suffix := " x%d" % active_stack.amount if active_stack.amount > 1 else ""
		hand_label.text = "HAND  %s  |  %s%s" % [source_name, display_name, suffix]
