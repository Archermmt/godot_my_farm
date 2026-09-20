class_name CalendarManagerService
extends CanvasModulate

var config: GameConfig:
	get:
		return DataCatalog.config

const DAYS_PER_MONTH := 30
const MONTHS_PER_YEAR := 12

var year: int = 1
var month: int = 1
var day: int = 1
var weekday: int = 1
var hour: int = 6
var minute: int = 0
var season_metas: Dictionary[SeasonMeta.SeasonType, SeasonMeta] = {}
var world_seed: int = 0

var calendar: CalendarManagerService:
	get:
		return self
var time_scale: float = 1.0
var _running := false
var _pause_reasons: Dictionary[StringName, bool] = {}
var _ending_day := false

var current_weather: StringName = &""
var _selection_key: String = ""
var _time_accumulator: float = 0.0
var _day_transition_overlay: ColorRect = null
const DAY_TRANSITION_LOCK := &"day_transition"


func _ready() -> void:
	var scene := get_tree().current_scene
	if scene != null:
		_day_transition_overlay = scene.get_node_or_null("UILayer/DayTransitionOverlay") as ColorRect
	if not EventBus.time_advanced.is_connected(_on_time_advanced):
		EventBus.time_advanced.connect(_on_time_advanced)
	if not EventBus.day_advanced.is_connected(_on_day_advanced):
		EventBus.day_advanced.connect(_on_day_advanced)


func setup() -> Array[String]:
	var errors: Array[String] = []
	if _day_transition_overlay != null:
		_day_transition_overlay.visible = false
	season_metas = config.season_metas
	world_seed = config.world_seed
	var season_types: Dictionary[int, bool] = {}
	for season_type: SeasonMeta.SeasonType in config.season_metas:
		var meta := config.season_metas[season_type] as SeasonMeta
		if meta == null:
			errors.append("season_metas[%d] is null" % season_type)
			continue
		if meta.season_type != season_type:
			errors.append("season_metas[%d].season_type must match dictionary key" % season_type)
			continue
		if season_types.has(meta.season_type):
			errors.append("season_metas contains duplicate season_type %d" % meta.season_type)
		season_types[meta.season_type] = true
		var total_weight := 0.0
		for weather_key: StringName in meta.weather_weights:
			var weight := meta.weather_weights[weather_key]
			if weather_key == &"":
				errors.append("season %d has empty weather id" % season_type)
			if weight <= 0.0 or is_nan(weight) or is_inf(weight):
				errors.append("season %d weather %s weight must be positive" % [season_type, weather_key])
				continue
			if not meta.weather_light_tints.has(weather_key):
				errors.append("season %d weather %s has no light tint" % [season_type, weather_key])
			total_weight += weight
		if total_weight <= 0.0:
			errors.append("season %d has no weather candidates" % season_type)
	for season_index: int in SeasonMeta.SeasonType.size():
		var season_type: SeasonMeta.SeasonType = season_index as SeasonMeta.SeasonType
		if not season_types.has(season_type):
			errors.append("season_type %d has no SeasonMeta" % season_type)
	var weather_ids: Dictionary[StringName, bool] = {}
	for season_definition: SeasonMeta in config.season_metas.values():
		if season_definition == null:
			continue
		for weather_key: StringName in season_definition.weather_weights:
			weather_ids[weather_key] = true
	for weather_key: StringName in weather_ids:
		if not config.weather_icons.has(weather_key) or config.weather_icons[weather_key] == null:
			errors.append("weather %s has no icon" % weather_key)
	if errors.is_empty():
		if config.initial_time_scale <= 0.0 or is_nan(config.initial_time_scale) or is_inf(config.initial_time_scale):
			errors.append("invalid initial time scale")
		else:
			time_scale = config.initial_time_scale
	if errors.is_empty():
		_ensure_weather(true)
		_refresh_light()
	return errors


func _process(delta: float) -> void:
	if delta <= 0.0 or not _running or not _pause_reasons.is_empty():
		return
	_time_accumulator += delta * time_scale
	var whole_minutes := floori(_time_accumulator)
	if whole_minutes <= 0:
		return
	_time_accumulator -= whole_minutes
	advance_minutes(whole_minutes)


func advance_minutes(minutes: int) -> Error:
	if minutes < 0:
		return ERR_INVALID_PARAMETER
	if minutes == 0:
		return OK
	for _index in range(minutes):
		var previous_day := day
		var previous_hour := hour
		add_minutes(1)
		EventBus.time_advanced.emit()
		if hour != previous_hour:
			EventBus.advanced_hour.emit()
		if day != previous_day:
			next_day()
	return OK


func next_day() -> Error:
	if _ending_day:
		return OK
	_ending_day = true
	call_deferred("_perform_day_transition")
	return OK


func _perform_day_transition() -> void:
	var player := GameManager.player
	if player == null:
		_ending_day = false
		return
	var error := player.lock_input(DAY_TRANSITION_LOCK)
	if error == OK:
		error = pause(DAY_TRANSITION_LOCK)
	if error == OK:
		await _iris_transition(true)
	if error == OK:
		add_minutes((24 * 60) - minute_of_day())
		hour = 6
		minute = 0
		_ensure_weather(true)
		EventBus.day_advanced.emit()
		# MapManager handles returning the player to the farm wake point from
		# this signal. Let its deferred map work finish before opening the iris.
		await get_tree().process_frame
		await get_tree().process_frame
		_ending_day = false
	if error != OK:
		_ending_day = false
	await _iris_transition(false)
	resume(DAY_TRANSITION_LOCK)
	player.unlock_input(DAY_TRANSITION_LOCK)
	if error != OK:
		push_error("[CalendarManager] day transition failed: %s" % error_string(error))


func _iris_transition(closing: bool) -> void:
	if _day_transition_overlay == null or _day_transition_overlay.material is not ShaderMaterial:
		return
	var shader_material := _day_transition_overlay.material as ShaderMaterial
	var size := _day_transition_overlay.size
	if size.x <= 0.0 or size.y <= 0.0:
		size = _day_transition_overlay.get_viewport_rect().size
	var center := GameManager.player.get_global_transform_with_canvas().origin
	var softness := 3.0 / maxf(size.y, 1.0)
	var maximum := 2.0
	var closed := -softness * 2.0
	var center_uv := Vector2(center.x / maxf(size.x, 1.0), center.y / maxf(size.y, 1.0))
	shader_material.set_shader_parameter(&"center", center_uv)
	shader_material.set_shader_parameter(&"softness", softness)
	_day_transition_overlay.visible = true
	var start_radius := maximum if closing else closed
	var end_radius := closed if closing else maximum
	shader_material.set_shader_parameter(&"radius", start_radius)
	var duration := maxf(config.day_transition_duration, 0.0)
	if duration > 0.0:
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_method(
			func(value: float) -> void: shader_material.set_shader_parameter(&"radius", value),
			start_radius,
			end_radius,
			duration
		)
		await tween.finished
	else:
		shader_material.set_shader_parameter(&"radius", end_radius)
	if not closing:
		_day_transition_overlay.visible = false


func start() -> void:
	_running = true


func stop() -> void:
	_running = false
	_pause_reasons.clear()
	_time_accumulator = 0.0


func pause(reason: StringName) -> Error:
	if reason == &"":
		return ERR_INVALID_PARAMETER
	_pause_reasons[reason] = true
	return OK


func resume(reason: StringName) -> Error:
	if reason == &"":
		return ERR_INVALID_PARAMETER
	if not _pause_reasons.erase(reason):
		return ERR_DOES_NOT_EXIST
	return OK


func is_paused() -> bool:
	return not _pause_reasons.is_empty()


func pause_reasons() -> Array[StringName]:
	var reasons: Array[StringName] = []
	reasons.assign(_pause_reasons.keys())
	reasons.sort()
	return reasons


func is_running() -> bool:
	return _running


func check_weather(weather_ids: Array[StringName]) -> bool:
	return current_weather in weather_ids


func refresh() -> void:
	_ensure_weather(true)
	_refresh_light()


func weather_icon(requested_weather_id: StringName = current_weather) -> Texture2D:
	return config.weather_icons.get(requested_weather_id, null) as Texture2D


func _ensure_weather(force: bool = false) -> void:
	var next_key := "%d:%d:%d:%d" % [world_seed, year, month, day]
	if not force and next_key == _selection_key:
		return
	var next_weather := weather_id()
	if next_weather == &"":
		return
	var previous_id := current_weather
	current_weather = next_weather
	_selection_key = next_key
	if is_instance_valid(EffectManager):
		EffectManager.play_effect(current_weather, [])
	EventBus.weather_changed.emit(current_weather, previous_id)


func _refresh_light() -> void:
	var time := float(hour) + float(minute) / 60.0
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
	var meta := season_meta()
	if meta != null and current_weather != &"":
		result *= meta.weather_light_tints.get(current_weather, Color.WHITE) as Color
	result.a = 1.0
	color = result


func _on_time_advanced() -> void:
	_refresh_light()


func _on_day_advanced() -> void:
	_ensure_weather()
	call_deferred("_refresh_light")


func season(month_value: int = month) -> SeasonMeta.SeasonType:
	var season_index := floori(float(clampi(month_value, 1, MONTHS_PER_YEAR) - 1) / 3.0)
	return clampi(season_index, SeasonMeta.SeasonType.SPRING, SeasonMeta.SeasonType.WINTER) as SeasonMeta.SeasonType


func season_meta(month_value: int = month) -> SeasonMeta:
	return season_metas.get(season(month_value), null) as SeasonMeta


func weather_id(month_value: int = month, year_value: int = year, day_value: int = day) -> StringName:
	var meta := season_meta(month_value)
	if meta == null:
		return &""
	var total_weight := 0.0
	for weather_key: StringName in meta.weather_weights:
		var weight: float = meta.weather_weights[weather_key]
		if weight > 0.0:
			total_weight += weight
	if total_weight <= 0.0:
		return &""
	var weather_ids: Array[StringName] = []
	weather_ids.assign(meta.weather_weights.keys())
	weather_ids.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:%d:%d:%d" % [world_seed, year_value, month_value, day_value, config.weather_selection_salt])
	var roll := rng.randf() * total_weight
	var fallback := &""
	for weather_key: StringName in weather_ids:
		var weight: float = meta.weather_weights[weather_key]
		if weight <= 0.0:
			continue
		fallback = weather_key
		roll -= weight
		if roll <= 0.0:
			return weather_key
	return fallback


func minute_of_day() -> int:
	return hour * 60 + minute


func add_minutes(amount: int) -> void:
	if amount <= 0:
		return
	var total := minute_of_day() + amount
	var days := floori(float(total) / (24.0 * 60.0))
	var remainder := posmod(total, 24 * 60)
	hour = floori(float(remainder) / 60.0)
	minute = posmod(remainder, 60)
	for _index in range(days):
		day += 1
		weekday = 1 + (weekday % 7)
		if day > DAYS_PER_MONTH:
			day = 1
			month += 1
			if month > MONTHS_PER_YEAR:
				month = 1
				year += 1


func to_dict() -> Dictionary:
	return {"year": year, "month": month, "day": day, "weekday": weekday, "hour": hour, "minute": minute}


func from_dict(data: Dictionary) -> Error:
	for key: String in ["year", "month", "day", "weekday", "hour", "minute"]:
		if not SerializationUtil.has_valid_int(data, key):
			return ERR_INVALID_DATA
	var next_year := int(data.year)
	var next_month := int(data.month)
	var next_day_value := int(data.day)
	var next_weekday := int(data.weekday)
	var next_hour := int(data.hour)
	var next_minute := int(data.minute)
	if next_year < 1 or next_month < 1 or next_month > MONTHS_PER_YEAR or next_day_value < 1 or next_day_value > DAYS_PER_MONTH:
		return ERR_INVALID_DATA
	if next_weekday < 1 or next_weekday > 7 or next_hour < 0 or next_hour > 23 or next_minute < 0 or next_minute > 59:
		return ERR_INVALID_DATA
	year = next_year
	month = next_month
	day = next_day_value
	weekday = next_weekday
	hour = next_hour
	minute = next_minute
	return OK
