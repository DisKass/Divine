class_name BuildingManager
extends RefCounted

## Zone of Responsibility: Tracking building counts, calculating building costs, 
## and checking tier unlock conditions based on Milestones.

var resource_manager: ResourceManager
var milestones_manager: MilestonesManager

# Number of active buildings per type: building_type (String) -> count (int)
var building_counts: Dictionary = {}

# building_type (String) -> BuildingCostData (Resource)
var cost_configs: Dictionary = {}

# GD Panel override: allow placing buildings for free
var free_buildings_mode: bool = false

func _init(res_mgr: ResourceManager, ms_mgr: MilestonesManager) -> void:
	resource_manager = res_mgr
	milestones_manager = ms_mgr
	_load_cost_configs()

func _load_cost_configs() -> void:
	# In a real large project, this could be loaded via DirAccess
	# We manually specify to ensure all are loaded securely
	var types = ["portal", "miner", "smelter", "converter", "assembler", "extractor", "infuser", "seller", "splitter_2", "splitter_3", "miner_iron", "miner_coal", "miner_crystal", "crusher", "constructor", "alchemy_lab", "artifact_altar"]
	for type in types:
		var path = "res://data/buildings/" + type + ".tres"
		if ResourceLoader.exists(path):
			cost_configs[type] = ResourceLoader.load(path)

## Returns whether a building type is unlocked under current milestone tier.
func is_building_unlocked(type: String) -> bool:
	if not cost_configs.has(type): return false
	var config: BuildingCostData = cost_configs[type]
	var current_tier = milestones_manager.get_current_tier()
	return current_tier >= config.tier

## Returns whether building count has reached max allowed count for building type.
func is_building_limit_reached(type: String) -> bool:
	if not cost_configs.has(type): return false
	var config: BuildingCostData = cost_configs[type]
	if config.max_count >= 0:
		var current_cnt = building_counts.get(type, 0)
		return current_cnt >= config.max_count
	return false

## Returns the required tier level to unlock a building type.
func get_building_required_tier(type: String) -> int:
	if not cost_configs.has(type): return 1
	var config: BuildingCostData = cost_configs[type]
	return config.tier

## Returns the cost dictionary for the next building of the specified type.
func get_building_cost(type: String) -> Dictionary:
	if not is_building_unlocked(type) or is_building_limit_reached(type):
		return {}
		
	var count = building_counts.get(type, 0)
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
func can_afford(type: String) -> bool:
	if not is_building_unlocked(type) or is_building_limit_reached(type):
		return false
	if free_buildings_mode:
		return true
	var cost = get_building_cost(type)
	return resource_manager.can_afford(cost)

## Processes the purchase of a building. Returns true if successful.
func buy_building(type: String) -> bool:
	if not can_afford(type):
		return false
		
	if free_buildings_mode:
		building_counts[type] = building_counts.get(type, 0) + 1
		return true

	var cost = get_building_cost(type)
	if resource_manager.spend(cost):
		building_counts[type] = building_counts.get(type, 0) + 1
		return true
	return false

## Processes the demolition of a building, refunding 100% of the cost.
func refund_building(type: String) -> void:
	var count = building_counts.get(type, 0)
	if count <= 0:
		return
		
	# Decrement count first so that get_building_cost returns the cost of the building being removed
	building_counts[type] = count - 1
	
	# We temporarily pretend it's unlocked and no limit reached to get its base cost back accurately
	var config: BuildingCostData = cost_configs.get(type)
	var refund_amount = {}
	if count - 1 == 0:
		for res in config.base_costs: refund_amount[res] = float(config.base_costs[res])
	else:
		var factor = pow(config.multiplier, (count - 1) - 1)
		for res in config.first_paid_costs: refund_amount[res] = snappedf(float(config.first_paid_costs[res]) * factor, 0.1)
	
	for res in refund_amount:
		resource_manager.add_resource(res, refund_amount[res])

## Serializes the building manager state.
func to_dict() -> Dictionary:
	return {
		"building_counts": building_counts.duplicate()
	}

## Deserializes and restores the building manager state.
func from_dict(dict: Dictionary) -> void:
	building_counts = dict.get("building_counts", {}).duplicate()
