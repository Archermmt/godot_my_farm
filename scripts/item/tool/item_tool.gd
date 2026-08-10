class_name ItemTool
extends Tool

const FACING_VECTORS := {
	&"up": Vector2(0, -1), &"down": Vector2(0, 1), &"left": Vector2(-1, 0), &"right": Vector2(1, 0)
}
@onready var tool_area: Area2D = get_node_or_null("ToolArea") as Area2D
@onready var tool_area_shape: CollisionShape2D = get_node_or_null("ToolArea/CollisionShape2D") as CollisionShape2D


func _ready() -> void:
	z_index = 4096
	z_as_relative = false
	top_level = true
	if visual != null:
		visual.visible = false
	if tool_area != null:
		tool_area.collision_layer = 0
		tool_area.collision_mask = 8
		tool_area.monitoring = false
		tool_area.visible = false
		tool_area.area_entered.connect(_on_tool_area_entered)
		tool_area.area_exited.connect(_on_tool_area_exited)
	if tool_area_shape != null:
		tool_area_shape.disabled = true


func begin_charge() -> Error:
	var result := super.begin_charge()
	if result == OK and tool_area != null:
		tool_area.collision_layer = 0
		tool_area.collision_mask = 8
		tool_area.monitoring = true
		tool_area.visible = true
		if tool_area_shape != null:
			tool_area_shape.disabled = false
	queue_redraw()
	return result


func update_charge(delta: float) -> void:
	super.update_charge(delta)
	if not charging:
		return
	var player := GameManager.player
	if player == null or tool_area == null or tool_area_shape == null:
		return
	global_position = player.global_position
	tool_area.global_position = player.global_position
	tool_area.rotation = FACING_VECTORS.get(player.facing, Vector2.DOWN).angle()
	var typed_meta := meta as ItemToolMeta
	var area_scale := typed_meta.level_scale(charge_level) if typed_meta != null else 1.0
	tool_area_shape.scale = Vector2.ONE * area_scale
	queue_redraw()


func cancel_charge() -> void:
	super.cancel_charge()
	if tool_area != null:
		tool_area.monitoring = false
		tool_area.visible = false
		tool_area.collision_layer = 0
		tool_area.collision_mask = 0
	if tool_area_shape != null:
		tool_area_shape.disabled = true
	for target: Harvestable in ItemManager.get_harvestables():
		ItemManager.unregister_harvestable(target)
	queue_redraw()


func _on_tool_area_entered(area: Area2D) -> void:
	if not charging or area == null or area.name != &"ToolArea":
		return
	var target := area.get_parent() as Harvestable
	var typed_meta := meta as ToolMeta
	var target_meta := target.meta as HarvestableMeta if target != null else null
	if (
		target != null
		and target_meta != null
		and typed_meta != null
		and target_meta.required_tool == typed_meta.tool_kind
	):
		ItemManager.register_harvestable(target, self)


func _on_tool_area_exited(area: Area2D) -> void:
	if area == null or area.name != &"ToolArea":
		return
	var target := area.get_parent() as Harvestable
	if target != null:
		ItemManager.unregister_harvestable(target)


func _draw() -> void:
	if not charging or tool_area_shape == null or not tool_area_shape.shape is ConvexPolygonShape2D:
		return
	var points := PackedVector2Array()
	for point: Vector2 in (tool_area_shape.shape as ConvexPolygonShape2D).points:
		points.append(to_local(tool_area_shape.to_global(point)))
	if points.size() < 3:
		return
	draw_colored_polygon(points, Color(0.95, 0.55, 0.25, 0.22))
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, Color("ffd080"), 2.0)
	for target: Harvestable in ItemManager.get_harvestables():
		draw_circle(to_local(target.global_position), 5.0, Color("ffe28a"))


func _use_impl() -> ApplyResult:
	var map := MapManager.current_map()
	var typed_meta := meta as ToolMeta
	var result := ApplyResult.new()
	var targets: Array[Harvestable] = ItemManager.get_harvestables()
	for target: Harvestable in targets:
		if target == null or not is_instance_valid(target):
			continue
		if (
			target.apply_tool(typed_meta.tool_kind, typed_meta.level_damage(charge_level))
			!= ItemMeta.ItemFlag.AVAILABLE
		):
			continue
		var target_cell := map.world_to_cell(target.global_position)
		var cell_state := map.get_cell(target_cell).state if map.get_cell(target_cell) != null else CellState.new()
		cell_state.coord = target_cell
		cell_state.usable = true
		cell_state.invalid = false
		result.cells[target_cell] = cell_state
		target.add_flag(ItemMeta.ItemFlag.DESTROYED if target.is_depleted() else ItemMeta.ItemFlag.HURT)
		result.items[target.item_id()] = target.state
		if target.is_depleted():
			for pickup_id: StringName in map.resolve_depleted_item(target.item_id()):
				var pickup := map.get_item(pickup_id)
				if pickup != null and pickup.state != null:
					result.items[pickup_id] = pickup.state
	return result
