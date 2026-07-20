class_name UpgradesManager
extends RefCounted

## Zone of Responsibility: Managing global upgrades progression and registering their bonuses with ModifierManager.

signal upgrade_purchased(upgrade_id: String, level: int)

var resource_manager: ResourceManager
var modifier_manager: ModifierManager

var upgrades: Dictionary = {} # upgrade_id -> current_level (int)
var upgrade_configs: Dictionary = {} # upgrade_id -> UpgradeData (Resource)

func _init(res_mgr: ResourceManager, mod_mgr: ModifierManager) -> void:
	resource_manager = res_mgr
	modifier_manager = mod_mgr
	_load_configs()

func _load_configs() -> void:
	var types = ["miner_speed", "factory_speed", "logistics_transfer"]
	for type in types:
		var path = "res://data/upgrades/" + type + ".tres"
		if ResourceLoader.exists(path):
			upgrade_configs[type] = ResourceLoader.load(path)

## Returns the purchased level for an upgrade.
func get_upgrade_level(id: String) -> int:
	return int(upgrades.get(id, 0))

## Returns cost dictionary for the next level of an upgrade.
func get_upgrade_cost(id: String) -> Dictionary:
	if not upgrade_configs.has(id): return {}
	var config: UpgradeData = upgrade_configs[id]
	var lvl = get_upgrade_level(id)
	
	if lvl >= config.max_level:
		return {} # Max level reached
		
	var cost_val = snappedf(config.base_cost * pow(config.cost_multiplier, lvl), 0.1)
	return { "credits": cost_val }

## Checks if player can afford the next level of upgrade.
func can_afford_upgrade(id: String) -> bool:
	var cost = get_upgrade_cost(id)
	if cost.is_empty():
		return false
	return resource_manager.can_afford(cost)

## Buys the next level of upgrade if affordable. Returns true if successful.
func buy_upgrade(id: String) -> bool:
	if not can_afford_upgrade(id):
		return false
	var cost = get_upgrade_cost(id)
	if resource_manager.spend(cost):
		var new_lvl = get_upgrade_level(id) + 1
		upgrades[id] = new_lvl
		
		# Register with modifier manager
		_update_modifiers(id)
		
		upgrade_purchased.emit(id, new_lvl)
		return true
	return false

func _update_modifiers(id: String) -> void:
	if not upgrade_configs.has(id): return
	var config: UpgradeData = upgrade_configs[id]
	var lvl = get_upgrade_level(id)
	var bonus = lvl * config.bonus_per_level
	modifier_manager.set_source_modifier("upgrades_" + id, id, bonus)

## Recalculates all active modifiers (useful after loading save).
func rebuild_modifiers() -> void:
	for id in upgrades:
		_update_modifiers(id)

## Serializes the upgrades manager state.
func to_dict() -> Dictionary:
	return {
		"upgrades": upgrades.duplicate()
	}

## Deserializes and restores the upgrades manager state.
func from_dict(dict: Dictionary) -> void:
	upgrades = dict.get("upgrades", {}).duplicate()
	rebuild_modifiers()
