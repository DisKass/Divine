class_name EconomyManager
extends RefCounted

## Manages global player resources, building cost scaling, and purchase/demolition economy.

# Global resources: resource_name (String) -> amount (float)
var resources: Dictionary = {
	"credits": 0.0,
	"coal": 0.0,
	"iron_ingot": 0.0,
	"mana_crystal": 0.0,
	"crystal_dust": 0.0,
	"crushed_iron": 0.0,
	"mana_essence": 0.0,
	"runesteel_ingot": 0.0
}

# Number of active buildings per type: building_type (String) -> count (int)
var building_counts: Dictionary = {}

# Cost configurations: building_type (String) -> Dictionary
# Config format:
# {
#   "multiplier": 1.15,
#   "base_costs": { "credits": 0.0 }, # Cost for count == 0
#   "first_paid_costs": { "credits": 10.0 } # Cost for count >= 1
# }
var cost_configs: Dictionary = {}

signal milestone_completed(tier: int, milestone_data: Dictionary)

const MILESTONES: Array[Dictionary] = [
	{
		"tier": 1,
		"name": "Industrial Foundation",
		"requirements": {
			"iron_plate": 20.0,
			"iron_gear": 10.0
		}
	},
	{
		"tier": 2,
		"name": "Alchemical Synthesis",
		"requirements": {
			"iron_ingot": 30.0,
			"mana_essence": 15.0
		}
	},
	{
		"tier": 3,
		"name": "Artifact Mastery",
		"requirements": {
			"runesteel_ingot": 10.0
		}
	}
]

var current_milestone_index: int = 0
var milestone_progress: Dictionary = {}

func _init() -> void:
	# Initialize default resources
	resources["credits"] = 85.0 # Starter credits
	resources["coal"] = 0.0
	resources["iron_ingot"] = 0.0
	resources["mana_crystal"] = 0.0
	resources["crystal_dust"] = 0.0
	resources["crushed_iron"] = 0.0
	resources["mana_essence"] = 0.0
	resources["runesteel_ingot"] = 0.0
	
	# Set up default cost configs
	cost_configs = {
		"portal": {
			"tier": 1,
			"multiplier": 1.0,
			"max_count": 1,
			"base_costs": { "credits": 50.0 },
			"first_paid_costs": { "credits": 50.0 }
		},
		"miner": {
			"tier": 1,
			"multiplier": 1.15,
			"base_costs": {}, # First miner is free!
			"first_paid_costs": { "credits": 10.0 }
		},
		"miner_iron": {
			"tier": 1,
			"multiplier": 1.15,
			"base_costs": {}, # First iron miner is free
			"first_paid_costs": { "credits": 15.0 }
		},
		"miner_coal": {
			"tier": 1,
			"multiplier": 1.15,
			"base_costs": { "credits": 25.0 },
			"first_paid_costs": { "credits": 50.0 }
		},
		"miner_crystal": {
			"tier": 2,
			"multiplier": 1.20,
			"base_costs": { "credits": 75.0 },
			"first_paid_costs": { "credits": 150.0 }
		},
		"crusher": {
			"tier": 1,
			"multiplier": 1.15,
			"base_costs": { "credits": 35.0 },
			"first_paid_costs": { "credits": 70.0 }
		},
		"smelter": {
			"tier": 1,
			"multiplier": 1.18,
			"base_costs": { "credits": 20.0 },
			"first_paid_costs": { "credits": 40.0 }
		},
		"constructor": {
			"tier": 1,
			"multiplier": 1.20,
			"base_costs": { "credits": 50.0 },
			"first_paid_costs": { "credits": 100.0 }
		},
		"alchemy_lab": {
			"tier": 2,
			"multiplier": 1.25,
			"base_costs": { "credits": 100.0 },
			"first_paid_costs": { "credits": 200.0 }
		},
		"artifact_altar": {
			"tier": 3,
			"multiplier": 1.30,
			"base_costs": { "credits": 250.0 },
			"first_paid_costs": { "credits": 500.0 }
		},
		"seller": {
			"tier": 1,
			"multiplier": 1.12,
			"base_costs": { "credits": 15.0 },
			"first_paid_costs": { "credits": 30.0 }
		}
	}

## Returns player's current unlocked tier index (1-based).
func get_current_tier() -> int:
	return current_milestone_index + 1

## Returns the required tier level to unlock a building type.
func get_building_required_tier(type: String) -> int:
	var config = cost_configs.get(type, {})
	return int(config.get("tier", 1))

## Returns whether a building type is unlocked under current milestone tier.
func is_building_unlocked(type: String) -> bool:
	var req_tier = get_building_required_tier(type)
	return get_current_tier() >= req_tier

## Returns whether building count has reached max allowed count for building type.
func is_building_limit_reached(type: String) -> bool:
	var config = cost_configs.get(type, {})
	if config.has("max_count"):
		var max_cnt = int(config["max_count"])
		var current_cnt = building_counts.get(type, 0)
		return current_cnt >= max_cnt
	return false

## Returns the cost dictionary for the next building of the specified type.
func get_building_cost(type: String) -> Dictionary:
	if not is_building_unlocked(type) or is_building_limit_reached(type):
		return {}
		
	var count = building_counts.get(type, 0)
	var config = cost_configs.get(type, {})
	if config.is_empty():
		return {}
		
	var cost = {}
	if count == 0:
		var base = config.get("base_costs", {})
		for res in base:
			cost[res] = base[res]
	else:
		var first_paid = config.get("first_paid_costs", {})
		var multiplier = float(config.get("multiplier", 1.15))
		var factor = pow(multiplier, count - 1)
		for res in first_paid:
			cost[res] = snappedf(first_paid[res] * factor, 0.1) # Snap to 1 decimal place
			
	return cost

## Checks if the player can afford a building.
func can_afford(type: String) -> bool:
	if not is_building_unlocked(type) or is_building_limit_reached(type):
		return false
	var cost = get_building_cost(type)
	for res in cost:
		if resources.get(res, 0.0) < cost[res]:
			return false
	return true


## Processes the purchase of a building. Returns true if successful.
func buy_building(type: String) -> bool:
	if not can_afford(type):
		return false
		
	var cost = get_building_cost(type)
	for res in cost:
		resources[res] -= cost[res]
		
	building_counts[type] = building_counts.get(type, 0) + 1
	return true

## Submits delivered resources from Portal and checks for milestone completion.
func submit_portal_resource(res_name: String, amount: float) -> void:
	if current_milestone_index >= MILESTONES.size():
		return # All milestones already completed
		
	var active_m = MILESTONES[current_milestone_index]
	var reqs: Dictionary = active_m.get("requirements", {})
	
	if reqs.has(res_name):
		var target = float(reqs[res_name])
		var current = milestone_progress.get(res_name, 0.0)
		var space = maxf(target - current, 0.0)
		var added = minf(amount, space)
		if added > 0.0:
			milestone_progress[res_name] = current + added
			check_milestone_completion()

## Checks if active milestone is fulfilled and advances to next.
func check_milestone_completion() -> void:
	if current_milestone_index >= MILESTONES.size():
		return
		
	var active_m = MILESTONES[current_milestone_index]
	var reqs: Dictionary = active_m.get("requirements", {})
	
	var is_fulfilled = true
	for res in reqs:
		if milestone_progress.get(res, 0.0) < float(reqs[res]):
			is_fulfilled = false
			break
			
	if is_fulfilled:
		var completed_m = active_m
		current_milestone_index += 1
		milestone_progress.clear()
		milestone_completed.emit(int(completed_m["tier"]), completed_m)

## Returns info on active milestone and progress.
func get_current_milestone() -> Dictionary:
	if current_milestone_index >= MILESTONES.size():
		return {
			"completed_all": true,
			"tier": MILESTONES.size(),
			"name": "All Milestones Completed",
			"requirements": {},
			"progress": {}
		}
	var m = MILESTONES[current_milestone_index].duplicate(true)
	m["completed_all"] = false
	m["progress"] = milestone_progress.duplicate()
	return m

## Processes the demolition of a building, decrementing the count and refunding 100% of the cost.
func refund_building(type: String) -> void:
	var count = building_counts.get(type, 0)
	if count <= 0:
		return
		
	# Decrement count first so that get_building_cost returns the cost of the building being removed
	building_counts[type] = count - 1
	
	var refund_amount = get_building_cost(type)
	for res in refund_amount:
		resources[res] = resources.get(res, 0.0) + refund_amount[res]

## Adds a resource amount (used by production outputs like global credits).
func add_resource(name: String, amount: float) -> void:
	resources[name] = resources.get(name, 0.0) + amount

## Gets current resource amount.
func get_resource(name: String) -> float:
	return resources.get(name, 0.0)

## Serializes the economy manager.
func to_dict() -> Dictionary:
	return {
		"resources": resources.duplicate(),
		"building_counts": building_counts.duplicate(),
		"current_milestone_index": current_milestone_index,
		"milestone_progress": milestone_progress.duplicate()
	}

## Deserializes and restores the economy manager.
func from_dict(dict: Dictionary) -> void:
	resources = dict.get("resources", {}).duplicate()
	building_counts = dict.get("building_counts", {}).duplicate()
	current_milestone_index = int(dict.get("current_milestone_index", 0))
	milestone_progress = dict.get("milestone_progress", {}).duplicate()

