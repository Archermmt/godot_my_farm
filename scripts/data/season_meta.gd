class_name SeasonMeta
extends Resource

enum SeasonType { SPRING, SUMMER, AUTUMN, WINTER }

@export var season_type: SeasonType = SeasonType.SPRING
@export var weather_weights: Dictionary[StringName, float] = {}
@export var weather_light_tints: Dictionary[StringName, Color] = {}
