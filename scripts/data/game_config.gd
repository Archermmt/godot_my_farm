class_name GameConfig
extends Resource

@export_category("Catalog")
@export var items: Dictionary[StringName, ItemMeta] = {}
@export var npc_schedules: Dictionary[StringName, NpcSchedule] = {}
@export var dialogue_definitions: Dictionary[StringName, Resource] = {}

@export_category("Game")
@export var default_world_seed: int = 12031992
@export var player_state_template: PlayerState = null
@export_range(0.1, 120.0, 0.1, "or_greater") var initial_time_scale: float = 1.0

@export_category("Scene")
@export_range(0.0, 5.0, 0.01, "or_greater") var transition_duration: float = 0.12
@export_range(0.0, 5.0, 0.01, "or_greater") var day_transition_duration: float = 0.55

@export_category("Weather")
@export var season_metas: Dictionary[StringName, SeasonMeta] = {}
@export var weather_icons: Dictionary[StringName, Texture2D] = {}
@export var weather_selection_salt: int = 7319
@export var morning_color: Color = Color("d9d5b8")
@export var noon_color: Color = Color.WHITE
@export var evening_color: Color = Color("d59a72")
@export var night_color: Color = Color("59657f")
@export_range(0.0, 1.0, 0.05) var interior_neutral_blend: float = 0.55

@export_category("Effects")
@export var effect_definitions: Dictionary[StringName, EffectDefinition] = {}
@export var weather_effect_scenes: Dictionary[StringName, PackedScene] = {}

@export_category("Audio Definitions")
@export var audio_definitions: Dictionary[StringName, AudioDefinition] = {}
@export_category("Audio Bus Volume")
@export_range(-80.0, 6.0, 0.5) var master_volume_db: float = 0.0
@export_range(-80.0, 6.0, 0.5) var music_volume_db: float = 0.0
@export_range(-80.0, 6.0, 0.5) var ambient_volume_db: float = 0.0
@export_range(-80.0, 6.0, 0.5) var sfx_volume_db: float = 0.0
@export_range(-80.0, 6.0, 0.5) var ui_volume_db: float = 0.0
@export_category("Audio Playback")
@export_range(0.0, 5.0, 0.05, "or_greater") var crossfade_duration: float = 0.45
@export_range(-80.0, 0.0, 0.5) var crossfade_floor_db: float = -40.0
@export_category("Audio Pool Limits")
@export_range(1, 16, 1) var music_pool_limit: int = 2
@export_range(1, 16, 1) var ambient_pool_limit: int = 2
@export_range(1, 64, 1) var sfx_pool_limit: int = 10
@export_range(1, 32, 1) var ui_pool_limit: int = 4
