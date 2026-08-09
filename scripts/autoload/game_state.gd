class_name GameStateService
extends Node

const INITIAL_TOOL_IDS: Array[StringName] = [
	&"tool_hoe",
	&"tool_watering_can",
	&"tool_sickle",
	&"tool_basket",
	&"tool_pickaxe",
	&"tool_axe",
]
const INITIAL_SEED_ID := &"seed_parsnip"
const INITIAL_SEED_AMOUNT := 15
const INITIAL_INVENTORY_CAPACITY := 20
const DEFAULT_WORLD_SEED := 12031992

var player: PlayerState = null
var inventory: InventoryState = null
var maps: Dictionary[StringName, MapState] = {}
var npcs: Dictionary[StringName, NpcState] = {}
var world_seed: int = 0
var current_slot: int = -1
var game_version: String = "0.1.0"

var _catalog_service: DataCatalogService = null
var _initialized: bool = false


func _ready() -> void:
	configure(DataCatalog)
	if _catalog_service != null and _catalog_service.is_ready_for_game():
		var error: Error = new_game(DEFAULT_WORLD_SEED)
		if error != OK:
			push_error("[GameState] failed to create default new game: %s" % error_string(error))


func configure(catalog_service: DataCatalogService) -> void:
	_catalog_service = catalog_service


func new_game(p_seed: int) -> Error:
	if _catalog_service == null or not _catalog_service.is_ready_for_game():
		return ERR_UNCONFIGURED

	var next_player := PlayerState.new()
	next_player.map_id = &"cabin"
	next_player.spawn_id = &"wake"
	next_player.cell = Vector2i(5, 4)
	next_player.facing = &"down"
	next_player.set_max_health(100)
	next_player.set_health(100)
	next_player.set_max_stamina(100)
	next_player.set_stamina(100)
	next_player.set_gold(500)

	var next_inventory := InventoryState.new(INITIAL_INVENTORY_CAPACITY, &"player")
	for item_id: StringName in INITIAL_TOOL_IDS:
		var definition: ItemDefinition = _catalog_service.get_item(item_id)
		if definition == null or not next_inventory.add_item(item_id, 1, definition.stack_limit):
			return ERR_INVALID_DATA
	var seed_definition: ItemDefinition = _catalog_service.get_item(INITIAL_SEED_ID)
	if seed_definition == null or not next_inventory.add_item(INITIAL_SEED_ID, INITIAL_SEED_AMOUNT, seed_definition.stack_limit):
		return ERR_INVALID_DATA

	var next_maps: Dictionary[StringName, MapState] = {}
	for map_id: StringName in [&"farm", &"field", &"cabin"]:
		var map_state := MapState.new()
		map_state.map_id = map_id
		next_maps[map_id] = map_state

	player = next_player
	inventory = next_inventory
	maps = next_maps
	npcs = {}
	world_seed = p_seed
	current_slot = -1
	_initialized = true
	EventBus.inventory_changed.emit(inventory.owner_id)
	EventBus.player_stats_changed.emit()
	print("[GameState] new game | seed=%d map=%s inventory=%d/%d" % [
		world_seed,
		player.map_id,
		used_inventory_slots(),
		inventory.capacity(),
	])
	return OK


func is_initialized() -> bool:
	return _initialized


func reset() -> void:
	player = null
	inventory = null
	maps.clear()
	npcs.clear()
	world_seed = 0
	current_slot = -1
	_initialized = false


func snapshot() -> Dictionary:
	if not _initialized:
		return {}
	var map_data: Array[Dictionary] = []
	var map_ids: Array[StringName] = []
	map_ids.assign(maps.keys())
	map_ids.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	for map_id: StringName in map_ids:
		map_data.append(maps[map_id].to_dict())
	var npc_data: Array[Dictionary] = []
	var npc_ids: Array[StringName] = []
	npc_ids.assign(npcs.keys())
	npc_ids.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	for npc_id: StringName in npc_ids:
		npc_data.append(npcs[npc_id].to_dict())
	return {
		"game_version": game_version,
		"world_seed": world_seed,
		"current_slot": current_slot,
		"player": player.to_dict(),
		"inventory": inventory.to_dict(),
		"maps": map_data,
		"npcs": npc_data,
	}.duplicate(true)


func replace_snapshot(data: Dictionary) -> Error:
	if not SerializationUtil.has_valid_string(data, "game_version"):
		return ERR_INVALID_DATA
	if not SerializationUtil.has_valid_int(data, "world_seed") or not SerializationUtil.has_valid_int(data, "current_slot"):
		return ERR_INVALID_DATA
	if not SerializationUtil.has_valid_dictionary(data, "player") or not SerializationUtil.has_valid_dictionary(data, "inventory"):
		return ERR_INVALID_DATA
	if not SerializationUtil.has_valid_array(data, "maps") or not SerializationUtil.has_valid_array(data, "npcs"):
		return ERR_INVALID_DATA

	var next_player := PlayerState.from_dict(data.get("player", {}) as Dictionary)
	var next_inventory := InventoryState.from_dict(data.get("inventory", {}) as Dictionary)
	if next_player == null or next_inventory == null:
		return ERR_INVALID_DATA
	var next_maps: Dictionary[StringName, MapState] = {}
	for raw_map: Variant in data.get("maps", []) as Array:
		if typeof(raw_map) != TYPE_DICTIONARY:
			return ERR_INVALID_DATA
		var map_state := MapState.from_dict(raw_map as Dictionary)
		if map_state == null or next_maps.has(map_state.map_id):
			return ERR_INVALID_DATA
		next_maps[map_state.map_id] = map_state
	if next_maps.is_empty() or not next_maps.has(next_player.map_id):
		return ERR_INVALID_DATA
	var next_npcs: Dictionary[StringName, NpcState] = {}
	for raw_npc: Variant in data.get("npcs", []) as Array:
		if typeof(raw_npc) != TYPE_DICTIONARY:
			return ERR_INVALID_DATA
		var npc_state := NpcState.from_dict(raw_npc as Dictionary)
		if npc_state == null or next_npcs.has(npc_state.npc_id) or not next_maps.has(npc_state.map_id):
			return ERR_INVALID_DATA
		next_npcs[npc_state.npc_id] = npc_state

	player = next_player
	inventory = next_inventory
	maps = next_maps
	npcs = next_npcs
	world_seed = int(data.get("world_seed", 0))
	current_slot = int(data.get("current_slot", -1))
	game_version = str(data.get("game_version", game_version))
	_initialized = true
	EventBus.inventory_changed.emit(inventory.owner_id)
	EventBus.player_stats_changed.emit()
	return OK


func set_npc(state: NpcState) -> Error:
	if state == null or state.npc_id == &"" or state.map_id == &"":
		return ERR_INVALID_PARAMETER
	if npcs.has(state.npc_id):
		return ERR_ALREADY_EXISTS
	if not maps.has(state.map_id):
		return ERR_DOES_NOT_EXIST
	npcs[state.npc_id] = state
	return OK


func get_npc(npc_id: StringName) -> NpcState:
	return npcs.get(npc_id, null) as NpcState


func startup_summary() -> String:
	if not _initialized:
		return "state=not_initialized"
	return "seed=%d map=%s units=%d slots=%d/%d hp=%d stamina=%d gold=%d" % [
		world_seed,
		player.map_id,
		inventory.count_item(INITIAL_SEED_ID) + INITIAL_TOOL_IDS.size(),
		used_inventory_slots(),
		inventory.capacity(),
		player.health,
		player.stamina,
		player.gold,
	]


func used_inventory_slots() -> int:
	if inventory == null:
		return 0
	var used: int = 0
	for stack: ItemStack in inventory.slots:
		if not stack.is_empty():
			used += 1
	return used
