class_name ItemMeta
extends Resource

enum ItemType { TOOL, SEED, FOOD, MATERIAL, OBSTACLE, PLANT, FURNITURE }
enum ItemFlag { AVAILABLE, DEPLETED, NOT_MATURE, WRONG_TOOL, INVALID, HURT, DESTROYED, PLANTED, DROPPED, GENERATED }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var item_type: ItemType = ItemType.MATERIAL
@export var can_pickup: bool = true
@export var dropable: bool = true
@export var icon_texture: Texture2D = null
@export var visual_offset: Vector2 = Vector2.ZERO
@export_range(1, 999, 1) var health: int = 1
@export_range(1, 999, 1) var stack_limit: int = 1
@export_range(0, 999999, 1) var buy_price: int = 0
@export_range(0, 999999, 1) var sell_price: int = 0
