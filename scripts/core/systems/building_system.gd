class_name BuildingSystem
extends RefCounted

## Zone of Responsibility: Tracking building counts, calculating building costs, 
## and checking tier unlock conditions based on Milestones.
## Operates on GameState.

# building_type (String) -> BuildingCostData (Resource)
static var cost_configs: Dictionary = {}
static var configs_loaded: bool = false

static func ensure_configs_loaded() -> void:
	if configs_loaded:
		return
	var types = ["portal", "miner", "smelter", "converter", "assembler", "extractor", "infuser", "seller", "splitter_2", "splitter_3", "miner_iron", "miner_coal", "miner_crystal", "crusher", "constructor", "alchemy_lab", "artifact_altar", "shell_forge", "shell_infuser", "purifier", "vault_gateway", "the_void"]

	for type in types:
		var path = "res://data/buildings/" + type + ".tres"
		if ResourceLoader.exists(path):
			cost_configs[type] = ResourceLoader.load(path)
	configs_loaded = true

## Returns the size in grid cells for the building type from its config or default map.
static func get_building_size(type: String) -> Vector2i:
	ensure_configs_loaded()
	if cost_configs.has(type):
		var config: BuildingCostData = cost_configs[type]
		if config != null and config.size_in_cells != Vector2i.ZERO:
			return config.size_in_cells
	return BuildingData.get_default_size(type)

## Returns whether a building type is unlocked under current milestone tier.
static func is_building_unlocked(state: GameState, type: String) -> bool:
	ensure_configs_loaded()
	if not cost_configs.has(type): return false
	var config: BuildingCostData = cost_configs[type]
	var current_tier = MilestoneSystem.get_current_tier(state)
	return current_tier >= config.tier

## Returns whether building count has reached max allowed count for building type.
static func is_building_limit_reached(state: GameState, type: String) -> bool:
	ensure_configs_loaded()
	if not cost_configs.has(type): return false
	var config: BuildingCostData = cost_configs[type]
	if config.max_count >= 0:
		var current_cnt = state.factory.building_counts.get(type, 0)
		return current_cnt >= config.max_count
	return false

## Returns the required tier level to unlock a building type.
static func get_building_required_tier(type: String) -> int:
	ensure_configs_loaded()
	if not cost_configs.has(type): return 1
	var config: BuildingCostData = cost_configs[type]
	return config.tier

## Returns the cost dictionary for the next building of the specified type.
static func get_building_cost(state: GameState, type: String) -> Dictionary:
	ensure_configs_loaded()
	if not is_building_unlocked(state, type) or is_building_limit_reached(state, type):
		return {}

	var count = state.factory.building_counts.get(type, 0)
	if not cost_configs.has(type): return {}
	var config: BuildingCostData = cost_configs[type]

	var cost = {}
	if count == 0:
		for res in config.base_costs:
			cost[res] = float(config.base_costs[res])
	else:
		var factor = pow(config.multiplier, count - 1)
		for res in config.first_paid_costs:
			cost[res] = snappedf(float(config.first_paid_costs[res]) * factor, 0.1)

	return cost

## Checks if the player can afford a building.
static func can_afford(state: GameState, type: String) -> bool:
	if not is_building_unlocked(state, type) or is_building_limit_reached(state, type):
		return false
	if state.free_buildings_mode:
		return true
	var cost = get_building_cost(state, type)
	return ResourceSystem.can_afford(state, cost)

## Processes the purchase of a building. Returns true if successful.
static func buy_building(state: GameState, type: String) -> bool:
	if not can_afford(state, type):
		return false

	if state.free_buildings_mode:
		state.factory.building_counts[type] = state.factory.building_counts.get(type, 0) + 1
		return true

	var cost = get_building_cost(state, type)
	if ResourceSystem.spend(state, cost):
		state.factory.building_counts[type] = state.factory.building_counts.get(type, 0) + 1
		return true
	return false

## Processes the demolition of a building, refunding 100% of the cost.
static func refund_building(state: GameState, type: String) -> void:
	ensure_configs_loaded()
	var count = state.factory.building_counts.get(type, 0)
	if count <= 0:
		return

	# Decrement count first so that get_building_cost returns the cost of the building being removed
	state.factory.building_counts[type] = count - 1

	# We temporarily pretend it's unlocked and no limit reached to get its base cost back accurately
	var config: BuildingCostData = cost_configs.get(type)
	if config == null:
		return

	var refund_amount = {}
	if count - 1 == 0:
		for res in config.base_costs: refund_amount[res] = float(config.base_costs[res])
	else:
		var factor = pow(config.multiplier, (count - 1) - 1)
		for res in config.first_paid_costs: refund_amount[res] = snappedf(float(config.first_paid_costs[res]) * factor, 0.1)

	for res in refund_amount:
		ResourceSystem.add_resource(state, res, refund_amount[res])

static func get_building_counts(state: GameState) -> Dictionary:
	return state.factory.building_counts.duplicate()

static func place_building(state: GameState, type: String, grid_pos: Vector2i) -> BuildingData:
	ensure_configs_loaded()
	var b_data = BuildingData.new(state.factory.next_id, type, grid_pos)
	state.factory.next_id += 1
	
	var config: BuildingCostData = cost_configs.get(type)
	if config and config.size_in_cells != Vector2i.ZERO:
		b_data.size_in_cells = config.size_in_cells

	state.factory.buildings[b_data.id] = b_data
	for cell in b_data.get_occupied_cells():
		state.factory.grid[cell] = b_data.id
		
	state.factory.rebuild_caches()
	return b_data

static func demolish_building(state: GameState, b_id: int) -> void:
	var b_data = state.factory.buildings.get(b_id)
	if not b_data: return
	
	refund_building(state, b_data.type)
	
	var conns_to_remove = []
	for c in state.factory.connections:
		if c.from_id == b_id or c.to_id == b_id:
			conns_to_remove.append(c)
	for c in conns_to_remove:
		state.factory.connections.erase(c)
		
	for cell in b_data.get_occupied_cells():
		state.factory.grid.erase(cell)
		
	state.factory.buildings.erase(b_id)
	state.factory.rebuild_caches()
