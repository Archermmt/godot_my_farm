class_name HarvestableMeta
extends ItemMeta

@export var required_tool: ToolMeta.ToolKind = ToolMeta.ToolKind.NONE
var max_health: int:
	get:
		return health
	set(value):
		health = value
@export var drops: Array[HarvestableDrop] = []
@export var depleted_replacement_id: StringName = &""
@export var blocks_movement: bool = true
@export var state_tags: Array[StringName] = []
@export var visual_stages: Array[HarvestableStage] = []
@export_category("Harvestable Animation")
@export_range(0.0, 2.0, 0.01, "or_greater") var hit_flash_hold_duration: float = 0.04
@export_range(0.0, 2.0, 0.01, "or_greater") var hit_flash_fade_duration: float = 0.12
@export_range(0.0, 2.0, 0.01, "or_greater") var depletion_white_duration: float = 0.08
@export_range(0.0, 5.0, 0.01, "or_greater") var depletion_dissolve_duration: float = 0.38
