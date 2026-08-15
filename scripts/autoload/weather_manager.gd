class_name WeatherManagerService
extends CanvasModulate

@export_category("Seasons")
@export var season_metas: Array[SeasonMeta] = []
@export var selection_salt: int = 7319
@export_category("Daylight")
@export var morning_color: Color = Color("d9d5b8")
@export var noon_color: Color = Color.WHITE
@export var evening_color: Color = Color("d59a72")
@export var night_color: Color = Color("59657f")
@export_range(0.0, 1.0, 0.05) var interior_neutral_blend: float = 0.55

var seasons: Dictionary[int, SeasonMeta] = {}
var current_weather: StringName = &""
var _month_seasons: Dictionary[int, SeasonMeta] = {}
var _selection_key: String = ""
var _map_id: StringName = &""
var _configuration_valid := false


func _ready() -> void:
	var errors := configure_seasons(season_metas)
	for error: String in errors:
		push_error("[WeatherManager] %s" % error)
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
	_map_id = SceneManager.current_map_id()
	_sync_game_calendar_season()
	_ensure_weather(true)
	_refresh_light()


func configure_seasons(entries: Array[SeasonMeta]) -> Array[String]:
	var errors := validate_configuration(entries)
	_configuration_valid = errors.is_empty()
	seasons.clear()
	_month_seasons.clear()
	if not _configuration_valid:
		return errors
	for meta: SeasonMeta in entries:
		seasons[meta.season_type] = meta
		for month: int in meta.months:
			_month_seasons[month] = meta
	return errors


func is_configured() -> bool:
	return _configuration_valid


func current_weather_id() -> StringName:
	return current_weather


func season_for_type(season_type: SeasonMeta.SeasonType) -> SeasonMeta:
	return seasons.get(season_type, null) as SeasonMeta


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
	rng.seed = hash("%d:%d:%d:%d:%d" % [world_seed, year, month, day, selection_salt])
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
		result = night_color
	elif time < 12.0:
		result = morning_color.lerp(noon_color, (time - 6.0) / 6.0)
	elif time < 18.0:
		result = noon_color.lerp(evening_color, (time - 12.0) / 6.0)
	elif time < 22.0:
		result = evening_color.lerp(night_color, (time - 18.0) / 4.0)
	else:
		result = night_color
	var meta := _current_season()
	if meta != null and current_weather != &"":
		result *= meta.weather_light_tints.get(current_weather, Color.WHITE) as Color
	result.a = 1.0
	return result.lerp(Color.WHITE, interior_neutral_blend) if interior else result


static func validate_configuration(entries: Array[SeasonMeta]) -> Array[String]:
	var errors: Array[String] = []
	var season_types: Dictionary[int, bool] = {}
	var season_ids: Dictionary[StringName, bool] = {}
	var covered_months: Dictionary[int, bool] = {}
	for index: int in entries.size():
		var meta := entries[index]
		if meta == null:
			errors.append("season_metas[%d] is null" % index)
			continue
		if meta.season_type < SeasonMeta.SeasonType.SPRING or meta.season_type > SeasonMeta.SeasonType.WINTER:
			errors.append("season_metas[%d] has invalid season_type" % index)
			continue
		if season_types.has(meta.season_type):
			errors.append("season_metas contains duplicate season_type %d" % meta.season_type)
		season_types[meta.season_type] = true
		if meta.season_id == &"":
			errors.append("season_metas[%d] has empty season_id" % index)
		elif season_ids.has(meta.season_id):
			errors.append("season_metas contains duplicate season_id %s" % meta.season_id)
		season_ids[meta.season_id] = true
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
	color = sampled_light_color(calendar.hour, calendar.minute, _map_id == &"cabin")


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


func _on_map_changed(map_id: StringName) -> void:
	_map_id = map_id
	_refresh_light()


func _on_player_state_changed(_state: PlayerState) -> void:
	_ensure_weather()
	_refresh_light()
