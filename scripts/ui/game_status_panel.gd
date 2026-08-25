class_name GameStatusPanel
extends Control

@onready var calendar_label: Label = $Panel/Calendar
@onready var player_label: Label = $Panel/Player
@onready var hand_label: Label = $Panel/Hand
@onready var weather_icon: TextureRect = $Panel/WeatherIcon
@onready var hand_icon: TextureRect = $Panel/HandIcon
@onready var hand_amount: Label = $Panel/HandAmount

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
	var player_node := MapManager.registered_player()
	var active_slot: BackpackSlot = player_node.backpack.active_slot() if player_node != null else null
	var weather_id := CalendarManager.current_weather_id() if is_instance_valid(CalendarManager) else &""
	var snapshot := (
		"%d/%d/%d/%d/%d/%d/%s|%d/%d/%d/%d/%d|%d/%s/%d"
		% [
			calendar.year,
			calendar.month,
			calendar.day,
			calendar.weekday,
			calendar.hour,
			calendar.minute,
			weather_id,
			player.health,
			player.max_health,
			player.energy,
			player.max_energy,
			player.gold,
			(
				GameManager.backpack_state.active_hand_source
				if GameManager.backpack_state != null
				else BackpackState.ActiveHandSource.NONE
			),
			active_slot.item_id if active_slot != null else &"",
			active_slot.amount if active_slot != null else 0,
		]
	)
	if snapshot == _last_snapshot:
		return
	_last_snapshot = snapshot
	calendar_label.text = (
		"Y%d M%d D%d W%d %02d:%02d\n%s"
		% [
			calendar.year,
			calendar.month,
			calendar.day,
			calendar.weekday,
			calendar.hour,
			calendar.minute,
			String(calendar.season()).left(3).to_upper(),
		]
	)
	weather_icon.texture = CalendarManager.weather_icon(weather_id) if is_instance_valid(CalendarManager) else null
	weather_icon.visible = weather_icon.texture != null
	weather_icon.tooltip_text = String(weather_id).capitalize()
	player_label.text = (
		"HP %d/%d  EN %d/%d  G %d"
		% [
			player.health,
			player.max_health,
			player.energy,
			player.max_energy,
			player.gold,
		]
	)
	if active_slot == null or active_slot.is_empty():
		hand_label.text = "Empty"
		hand_icon.texture = null
		hand_icon.visible = false
		hand_icon.tooltip_text = ""
		hand_amount.text = ""
	else:
		var meta := DataCatalog.get_item(active_slot.item_id)
		hand_label.text = meta.display_name if meta != null else String(active_slot.item_id)
		hand_icon.texture = meta.icon_texture if meta != null else null
		hand_icon.visible = hand_icon.texture != null
		hand_icon.tooltip_text = meta.display_name if meta != null else String(active_slot.item_id)
		hand_amount.text = "x%d" % active_slot.amount if active_slot.amount > 1 else ""
