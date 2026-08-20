class_name CalendarManagerService
extends CanvasModulate

const DEFAULT_CONFIG_PATH := "res://data/game_config.tres"

var config: GameConfig = load(DEFAULT_CONFIG_PATH) as GameConfig

var current_weather: StringName = &""
var _month_seasons: Dictionary[int, SeasonMeta] = {}
var _selection_key: String = ""
var _interior := false
var _configuration_valid := false
var _time_accumulator: float = 0.0


func configure_time_scale(value: float) -> Error:
	if value <= 0.0 or is_nan(value) or is_inf(value):
		return ERR_INVALID_PARAMETER
	if is_instance_valid(GameManager):
		GameManager.time_scale = value
	_time_accumulator = 0.0
	return OK


func advance_minutes(minutes: int) -> Error:
	if not is_instance_valid(GameManager) or not GameManager.is_initialized():
		return ERR_UNCONFIGURED
	if minutes < 0:
		return ERR_INVALID_PARAMETER
	if minutes == 0:
		return OK
	for _index in range(minutes):
		var before := GameManager.calendar.to_dict()
		GameManager.calendar.add_minutes(1)
		GameManager.sync_calendar_season()
		EventBus.time_advanced.emit(1, before, 1)
		if GameManager.calendar.hour >= 23:
			GameManager._refresh_npc_schedules()
			return GameManager.request_end_day()
	GameManager._refresh_npc_schedules()
	return OK


func advance_to_next_day() -> int:
	if not is_instance_valid(GameManager) or GameManager.calendar == null:
		return -1
	var previous_day := GameManager.calendar.day
	GameManager.calendar.add_minutes((24 * 60) - GameManager.calendar.minute_of_day())
	GameManager.calendar.hour = 6
	GameManager.calendar.minute = 0
	GameManager.sync_calendar_season()
	return previous_day


func request_sleep() -> Error:
	return GameManager.request_end_day()


func _process(delta: float) -> void:
	if delta <= 0.0 or not is_instance_valid(GameManager) or not GameManager.is_initialized() or not GameManager.can_advance():
		return
	_time_accumulator += delta * GameManager.time_scale
	var whole_minutes := floori(_time_accumulator)
	if whole_minutes <= 0:
		return
	_time_accumulator -= whole_minutes
	advance_minutes(whole_minutes)


func _ready() -> void:
	var errors := _build_season_index(config.season_metas)
	errors.append_array(validate_weather_icons(config.weather_icons, config.season_metas))
	_configuration_valid = errors.is_empty()
	for error: String in errors:
		push_error("[CalendarManager] %s" % error)
	if not _configuration_valid:
		color = Color.WHITE
		return
	if not EventBus.time_advanced.is_connected(_on_time_advanced):
		EventBus.time_advanced.connect(_on_time_advanced)
	if not EventBus.day_advanced.is_connected(_on_day_advanced):
		EventBus.day_advanced.connect(_on_day_advanced)
	if not EventBus.map_changed.is_connected(_on_map_changed):
		EventBus.map_changed.connect(_on_map_changed)
	if not EventBus.player_state_changed.is_connected(_on_player_state_changed):
		EventBus.player_state_changed.connect(_on_player_state_changed)
	if not EventBus.player_interior_changed.is_connected(_on_player_interior_changed):
		EventBus.player_interior_changed.connect(_on_player_interior_changed)
	_sync_game_calendar_season()
	_ensure_weather(true)
	_refresh_light()


func configure_seasons(entries: Dictionary[StringName, SeasonMeta]) -> Array[String]:
	var errors := _build_season_index(entries)
	if not errors.is_empty():
		return errors
	config = config.duplicate() as GameConfig
	config.season_metas = entries.duplicate()
	return errors


func _build_season_index(entries: Dictionary[StringName, SeasonMeta]) -> Array[String]:
	var errors := validate_configuration(entries)
	_configuration_valid = errors.is_empty()
	_month_seasons.clear()
	if not _configuration_valid:
		return errors
	for meta: SeasonMeta in entries.values():
		for month: int in meta.months:
			_month_seasons[month] = meta
	return errors


func is_configured() -> bool:
	return _configuration_valid


func current_weather_id() -> StringName:
	return current_weather


func refresh() -> void:
	_sync_game_calendar_season()
	_ensure_weather(true)
	_refresh_light()


func weather_icon(weather_id: StringName = current_weather) -> Texture2D:
	return config.weather_icons.get(weather_id, null) as Texture2D


func season_for_type(season_type: SeasonMeta.SeasonType) -> SeasonMeta:
	for meta: SeasonMeta in config.season_metas.values():
		if meta.season_type == season_type:
			return meta
	return null


func season_for_month(month: int) -> SeasonMeta:
	return _month_seasons.get(clampi(month, 1, CalendarState.MONTHS_PER_YEAR), null) as SeasonMeta


func season_id_for_month(month: int) -> StringName:
	var meta := season_for_month(month)
	return meta.season_id if meta != null else &""


func weather_for_date(month: int, world_seed: int, year: int, day: int) -> StringName:
	var meta := season_for_month(month)
	if meta == null:
		return &""
	var total_weight := 0.0
	for weather_id: StringName in meta.weather_weights:
		var weight := meta.weather_weights[weather_id]
		if weight > 0.0:
			total_weight += weight
	if total_weight <= 0.0:
		return &""
	var weather_ids: Array[StringName] = []
	weather_ids.assign(meta.weather_weights.keys())
	weather_ids.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:%d:%d:%d" % [world_seed, year, month, day, config.weather_selection_salt])
	var roll := rng.randf() * total_weight
	var fallback := &""
	for weather_id: StringName in weather_ids:
		var weight := meta.weather_weights[weather_id]
		if weight <= 0.0:
			continue
		fallback = weather_id
		roll -= weight
		if roll <= 0.0:
			return weather_id
	return fallback


func sampled_light_color(hour: int, minute: int, interior: bool = false) -> Color:
	var time := float(clampi(hour, 0, 23)) + float(clampi(minute, 0, 59)) / 60.0
	var result: Color
	if time < 6.0:
		result = config.night_color
	elif time < 12.0:
		result = config.morning_color.lerp(config.noon_color, (time - 6.0) / 6.0)
	elif time < 18.0:
		result = config.noon_color.lerp(config.evening_color, (time - 12.0) / 6.0)
	elif time < 22.0:
		result = config.evening_color.lerp(config.night_color, (time - 18.0) / 4.0)
	else:
		result = config.night_color
	var meta := _current_season()
	if meta != null and current_weather != &"":
		result *= meta.weather_light_tints.get(current_weather, Color.WHITE) as Color
	result.a = 1.0
	return result.lerp(Color.WHITE, config.interior_neutral_blend) if interior else result


static func validate_configuration(entries: Dictionary[StringName, SeasonMeta]) -> Array[String]:
	var errors: Array[String] = []
	var season_types: Dictionary[int, bool] = {}
	var covered_months: Dictionary[int, bool] = {}
	for season_id: StringName in entries:
		var meta := entries[season_id] as SeasonMeta
		if season_id == &"":
			errors.append("season_metas contains an empty key")
			continue
		if meta == null:
			errors.append("season_metas[%s] is null" % season_id)
			continue
		if meta.season_id != season_id:
			errors.append("season_metas[%s].season_id must match dictionary key, got %s" % [season_id, meta.season_id])
			continue
		if meta.season_type < SeasonMeta.SeasonType.SPRING or meta.season_type > SeasonMeta.SeasonType.WINTER:
			errors.append("season_metas[%s] has invalid season_type" % season_id)
			continue
		if season_types.has(meta.season_type):
			errors.append("season_metas contains duplicate season_type %d" % meta.season_type)
		season_types[meta.season_type] = true
		if meta.months.is_empty():
			errors.append("season %s has no months" % meta.season_id)
		for month: int in meta.months:
			if month < 1 or month > CalendarState.MONTHS_PER_YEAR:
				errors.append("season %s has invalid month %d" % [meta.season_id, month])
				continue
			if covered_months.has(month):
				errors.append("month %d is assigned to multiple seasons" % month)
			covered_months[month] = true
		var total_weight := 0.0
		for weather_id: StringName in meta.weather_weights:
			var weight := meta.weather_weights[weather_id]
			if weather_id == &"":
				errors.append("season %s has empty weather id" % meta.season_id)
			if weight <= 0.0 or is_nan(weight) or is_inf(weight):
				errors.append("season %s weather %s weight must be positive" % [meta.season_id, weather_id])
				continue
			if not meta.weather_light_tints.has(weather_id):
				errors.append("season %s weather %s has no light tint" % [meta.season_id, weather_id])
			total_weight += weight
		if total_weight <= 0.0:
			errors.append("season %s has no weather candidates" % meta.season_id)
	for season_type: int in SeasonMeta.SeasonType.size():
		if not season_types.has(season_type):
			errors.append("season_type %d has no SeasonMeta" % season_type)
	for month: int in range(1, CalendarState.MONTHS_PER_YEAR + 1):
		if not covered_months.has(month):
			errors.append("month %d has no season" % month)
	return errors


static func validate_weather_icons(
	icons: Dictionary[StringName, Texture2D],
	seasons: Dictionary[StringName, SeasonMeta]
) -> Array[String]:
	var errors: Array[String] = []
	var weather_ids: Dictionary[StringName, bool] = {}
	for season: SeasonMeta in seasons.values():
		if season == null:
			continue
		for weather_id: StringName in season.weather_weights:
			weather_ids[weather_id] = true
	for weather_id: StringName in weather_ids:
		if not icons.has(weather_id) or icons[weather_id] == null:
			errors.append("weather %s has no icon" % weather_id)
	return errors


func _ensure_weather(force: bool = false) -> void:
	if not _configuration_valid or not is_instance_valid(GameManager) or not GameManager.is_initialized():
		return
	var calendar: CalendarState = GameManager.calendar
	var next_key := "%d:%d:%d:%d" % [GameManager.world_seed, calendar.year, calendar.month, calendar.day]
	if not force and next_key == _selection_key:
		return
	_sync_game_calendar_season()
	var next_weather := weather_for_date(calendar.month, GameManager.world_seed, calendar.year, calendar.day)
	if next_weather == &"":
		return
	var previous_id := current_weather_id()
	current_weather = next_weather
	_selection_key = next_key
	EventBus.weather_changed.emit(current_weather_id(), previous_id)


func _refresh_light() -> void:
	if not is_instance_valid(GameManager) or GameManager.calendar == null:
		return
	var calendar: CalendarState = GameManager.calendar
	color = sampled_light_color(calendar.hour, calendar.minute, _interior)


func _current_season() -> SeasonMeta:
	if not is_instance_valid(GameManager) or GameManager.calendar == null:
		return null
	return season_for_month(GameManager.calendar.month)


func _sync_game_calendar_season() -> void:
	if not is_instance_valid(GameManager) or GameManager.calendar == null:
		return
	GameManager.sync_calendar_season()


func _on_time_advanced(_unit: int, _before: Dictionary, _delta: int) -> void:
	_sync_game_calendar_season()
	_refresh_light()


func _on_day_advanced(_previous_day: int, _current_day: int) -> void:
	_ensure_weather()
	call_deferred("_refresh_light")


func _on_map_changed(_map_id: StringName) -> void:
	_interior = false
	_refresh_light()


func _on_player_interior_changed(interior: bool) -> void:
	_interior = interior
	_refresh_light()


func _on_player_state_changed(_state: PlayerState) -> void:
	_ensure_weather()
	_refresh_light()
