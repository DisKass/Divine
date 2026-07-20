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
signal upgrade_purchased(upgrade_id: String, level: int)
signal artifact_crafted(artifact_id: String, new_count: int)
signal artifact_equipped(slot_idx: int, artifact_id: String)
signal artifact_unequipped(slot_idx: int, artifact_id: String)

const ARTIFACT_CONFIGS: Dictionary = {
	"runesteel_amulet": {
		"name": "Runesteel Amulet",
		"description": "+25% Factory Speed & +25% Logistics",
		"modifiers": {
			"factory_speed": 0.25,
			"logistics_transfer": 0.25
		}
	},
	"ring_of_wealth": {
		"name": "Ring of Wealth",
		"description": "+50% Selling Credit Income",
		"modifiers": {
			"sell_price_mult": 0.50
		}
	},
	"philosophers_stone": {
		"name": "Philosopher's Stone",
		"description": "+50% Mining Speed & +50% Factory Speed",
		"modifiers": {
			"miner_speed": 0.50,
			"factory_speed": 0.50
		}
	}
}

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

const UPGRADE_CONFIGS: Dictionary = {
	"miner_speed": {
		"name": "Mining Drill Overclock",
		"description": "Increases mining speed of all miners (+15% per lvl).",
		"base_cost": 50.0,
		"cost_multiplier": 1.5,
		"max_level": 10,
		"bonus_per_level": 0.15
	},
	"factory_speed": {
		"name": "Factory Processing Boost",
		"description": "Increases speed of smelters, crushers, labs & altars (+20% per lvl).",
		"base_cost": 75.0,
		"cost_multiplier": 1.6,
		"max_level": 10,
		"bonus_per_level": 0.20
	},
	"logistics_transfer": {
		"name": "High-Speed Pipelines",
		"description": "Increases connection transfer rate between buildings (+50% per lvl).",
		"base_cost": 100.0,
		"cost_multiplier": 1.7,
		"max_level": 10,
		"bonus_per_level": 0.50
	}
}

var current_milestone_index: int = 0
var milestone_progress: Dictionary = {}
var upgrades: Dictionary = {}
var artifact_inventory: Dictionary = {}
var equipped_artifacts: Array[String] = ["", ""]



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

## Returns the purchased level for an upgrade.
func get_upgrade_level(id: String) -> int:
	return int(upgrades.get(id, 0))

## Returns cost dictionary for the next level of an upgrade.
func get_upgrade_cost(id: String) -> Dictionary:
	var config = UPGRADE_CONFIGS.get(id, {})
	if config.is_empty():
		return {}
	var lvl = get_upgrade_level(id)
	var max_lvl = int(config.get("max_level", 10))
	if lvl >= max_lvl:
		return {} # Max level reached
	var base = float(config.get("base_cost", 50.0))
	var mult = float(config.get("cost_multiplier", 1.5))
	var cost_val = snappedf(base * pow(mult, lvl), 0.1)
	return { "credits": cost_val }

## Returns total bonus multiplier fraction for an upgrade (e.g. 0.3 for +30%).
func get_upgrade_bonus(id: String) -> float:
	var config = UPGRADE_CONFIGS.get(id, {})
	if config.is_empty():
		return 0.0
	var lvl = get_upgrade_level(id)
	var per_lvl = float(config.get("bonus_per_level", 0.1))
	return lvl * per_lvl

## Checks if player can afford the next level of upgrade.
func can_afford_upgrade(id: String) -> bool:
	var cost = get_upgrade_cost(id)
	if cost.is_empty():
		return false
	var cost_val = cost.get("credits", 0.0)
	return get_resource("credits") >= cost_val

## Buys the next level of upgrade if affordable. Returns true if successful.
func buy_upgrade(id: String) -> bool:
	if not can_afford_upgrade(id):
		return false
	var cost = get_upgrade_cost(id)
	var cost_val = cost.get("credits", 0.0)
	resources["credits"] -= cost_val
	var new_lvl = get_upgrade_level(id) + 1
	upgrades[id] = new_lvl
	upgrade_purchased.emit(id, new_lvl)
	return true

## Adds crafted artifact to global inventory.
func add_artifact_to_inventory(artifact_id: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	var current = int(artifact_inventory.get(artifact_id, 0))
	var new_count = current + amount
	artifact_inventory[artifact_id] = new_count
	artifact_crafted.emit(artifact_id, new_count)

## Equips an artifact using shift/push queue logic.
## If free slot exists, inserts into first free slot.
## If all slots full, expels last slot item to inventory, shifts slots right, and inserts new item at Slot 0.
func equip_artifact(arg1: Variant, arg2: Variant = null) -> bool:
	var artifact_id: String = ""
	var requested_slot: int = -1
	
	if arg1 is int and arg2 is String:
		requested_slot = int(arg1)
		artifact_id = String(arg2)
	elif arg1 is String:
		artifact_id = String(arg1)
		if arg2 is int:
			requested_slot = int(arg2)
			
	if not ARTIFACT_CONFIGS.has(artifact_id):
		return false
	var count = int(artifact_inventory.get(artifact_id, 0))
	if count <= 0:
		return false
		
	# Find first free slot
	var free_idx = -1
	for i in range(equipped_artifacts.size()):
		if equipped_artifacts[i] == "":
			free_idx = i
			break
			
	if free_idx != -1:
		# Put in first free slot
		artifact_inventory[artifact_id] = count - 1
		equipped_artifacts[free_idx] = artifact_id
		artifact_equipped.emit(free_idx, artifact_id)
		return true
		
	# All slots full: expel last slot to inventory and shift right
	var last_idx = equipped_artifacts.size() - 1
	var expelled_id = equipped_artifacts[last_idx]
	if expelled_id != "":
		artifact_inventory[expelled_id] = int(artifact_inventory.get(expelled_id, 0)) + 1
		artifact_unequipped.emit(last_idx, expelled_id)
		
	for i in range(last_idx, 0, -1):
		equipped_artifacts[i] = equipped_artifacts[i - 1]
		if equipped_artifacts[i] != "":
			artifact_equipped.emit(i, equipped_artifacts[i])
			
	artifact_inventory[artifact_id] = int(artifact_inventory.get(artifact_id, 0)) - 1
	equipped_artifacts[0] = artifact_id
	artifact_equipped.emit(0, artifact_id)
	return true


## Unequips an artifact from slot_idx back into inventory.
func unequip_artifact(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= equipped_artifacts.size():
		return
	var current_id = equipped_artifacts[slot_idx]
	if current_id == "":
		return
	equipped_artifacts[slot_idx] = ""
	artifact_inventory[current_id] = int(artifact_inventory.get(current_id, 0)) + 1
	artifact_unequipped.emit(slot_idx, current_id)

## Returns total sum of bonus for a modifier_name from all currently equipped artifacts.
func get_equipped_modifier_bonus(modifier_name: String) -> float:
	var total_bonus = 0.0
	for art_id in equipped_artifacts:
		if art_id != "" and ARTIFACT_CONFIGS.has(art_id):
			var mods: Dictionary = ARTIFACT_CONFIGS[art_id].get("modifiers", {})
			total_bonus += float(mods.get(modifier_name, 0.0))
	return total_bonus

## Serializes the economy manager.
func to_dict() -> Dictionary:
	return {
		"resources": resources.duplicate(),
		"building_counts": building_counts.duplicate(),
		"current_milestone_index": current_milestone_index,
		"milestone_progress": milestone_progress.duplicate(),
		"upgrades": upgrades.duplicate(),
		"artifact_inventory": artifact_inventory.duplicate(),
		"equipped_artifacts": equipped_artifacts.duplicate()
	}

## Deserializes and restores the economy manager.
func from_dict(dict: Dictionary) -> void:
	resources = dict.get("resources", {}).duplicate()
	building_counts = dict.get("building_counts", {}).duplicate()
	current_milestone_index = int(dict.get("current_milestone_index", 0))
	milestone_progress = dict.get("milestone_progress", {}).duplicate()
	upgrades = dict.get("upgrades", {}).duplicate()
	artifact_inventory = dict.get("artifact_inventory", {}).duplicate()
	
	var saved_eq = dict.get("equipped_artifacts", ["", ""])
	equipped_artifacts = ["", ""]
	for i in range(min(saved_eq.size(), 2)):
		equipped_artifacts[i] = String(saved_eq[i])



