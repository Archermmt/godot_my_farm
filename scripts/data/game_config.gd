class_name GameConfig
extends Resource

# Temporary source-compatibility hooks for older tooling. They are deliberately
# not exported and are ignored by snapshot restore.
var player_state_template: PlayerState = null
var backpack_state_template: BackpackState = null

@export_category("Catalog")
@export var items: Dictionary[StringName, ItemMeta] = {}
@export var npc_schedules: Dictionary[StringName, NpcSchedule] = {}
@export var dialogue_definitions: Dictionary[StringName, Resource] = {}

@export_category("Game")
@export var default_world_seed: int = 12031992
@export_range(0.1, 120.0, 0.1, "or_greater") var initial_time_scale: float = 1.0

@export_category("Player")
@export var player_map_id: StringName = &"farm"
@export var player_spawn_id: StringName = &"default"
@export var player_cell: Vector2i = Vector2i(5, 4)
@export_enum("up", "down", "left", "right") var player_facing: String = "down"
@export_range(1, 999, 1) var player_max_health: int = 100
@export_range(0, 999, 1) var player_initial_health: int = 100
@export_range(1, 999, 1) var player_max_energy: int = 100
@export_range(0, 999, 1) var player_initial_energy: int = 100
@export_range(0, 999999, 1) var player_initial_gold: int = 500
@export_range(1.0, 500.0, 1.0) var player_run_speed: float = 96.0
@export_range(1.0, 500.0, 1.0) var player_walk_speed: float = 48.0
@export_range(1.0, 160.0, 1.0) var player_pickup_radius: float = 72.0
@export_range(1.0, 64.0, 1.0) var player_pickup_collect_distance: float = 10.0
@export var player_trace_delay: Dictionary[StringName, float] = {
	&"drop": 1.0,
	&"harvestable": 0.5,
	&"generate": 0.0,
}
@export var player_pickup_speed_curve: Curve = null
@export var player_indoor_camera_zoom: Vector2 = Vector2(1.5, 1.5)
@export_range(0.0, 2.0, 0.05) var player_camera_zoom_duration: float = 0.3

@export_category("Backpack")
@export_range(0, 999, 1) var backpack_main_space_capacity: int = 20
@export_range(0, 999, 1) var backpack_toolbar_capacity: int = 6
@export_range(0, 999, 1) var backpack_itembar_capacity: int = 10
@export var backpack_initial_slots: Dictionary[StringName, BackpackSlot] = {}

@export_category("Map")
@export_range(0.0, 5.0, 0.01, "or_greater") var transition_duration: float = 0.12
@export_range(0.0, 5.0, 0.01, "or_greater") var day_transition_duration: float = 0.55

@export_category("Calender")
@export var season_metas: Dictionary[StringName, SeasonMeta] = {}
@export var weather_icons: Dictionary[StringName, Texture2D] = {}
@export var weather_selection_salt: int = 7319
@export var morning_color: Color = Color("d9d5b8")
@export var noon_color: Color = Color.WHITE
@export var evening_color: Color = Color("d59a72")
@export var night_color: Color = Color("59657f")
@export_range(0.0, 1.0, 0.05) var interior_neutral_blend: float = 0.55

@export_category("Effect")
@export var effect_definitions: Dictionary[StringName, EffectDefinition] = {}
@export var weather_effect_scenes: Dictionary[StringName, PackedScene] = {}

@export_category("Audio")
@export var audio_definitions: Dictionary[StringName, AudioDefinition] = {}
@export_range(-80.0, 6.0, 0.5) var master_volume_db: float = 0.0
@export_range(-80.0, 6.0, 0.5) var music_volume_db: float = 0.0
@export_range(-80.0, 6.0, 0.5) var ambient_volume_db: float = 0.0
@export_range(-80.0, 6.0, 0.5) var sfx_volume_db: float = 0.0
@export_range(-80.0, 6.0, 0.5) var ui_volume_db: float = 0.0
@export_range(0.0, 5.0, 0.05, "or_greater") var crossfade_duration: float = 0.45
@export_range(-80.0, 0.0, 0.5) var crossfade_floor_db: float = -40.0
@export_range(1, 16, 1) var music_pool_limit: int = 2
@export_range(1, 16, 1) var ambient_pool_limit: int = 2
@export_range(1, 64, 1) var sfx_pool_limit: int = 10
@export_range(1, 32, 1) var ui_pool_limit: int = 4
