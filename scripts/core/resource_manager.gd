class_name ResourceManager
extends RefCounted

## Zone of Responsibility: Storing and modifying player resource balances (Credits, Ores, etc.). 
## Validates transactions (affordability). Does NOT handle building costs or prices directly.

var balances: Dictionary = {}

func _init() -> void:
	# Initialize default resources
	balances["credits"] = 85.0
	balances["coal"] = 0.0
	balances["iron_ingot"] = 0.0
	balances["mana_crystal"] = 0.0
	balances["crystal_dust"] = 0.0
	balances["crushed_iron"] = 0.0
	balances["mana_essence"] = 0.0
	balances["runesteel_ingot"] = 0.0

## Adds a resource amount.
func add_resource(name: String, amount: float) -> void:
	balances[name] = balances.get(name, 0.0) + amount

## Gets current resource amount.
func get_resource(name: String) -> float:
	return balances.get(name, 0.0)

## Checks if the player can afford a specific dictionary of costs.
## cost_dict is format: {"credits": 50.0, "iron_plate": 10.0}
func can_afford(cost_dict: Dictionary) -> bool:
	for res in cost_dict:
		if get_resource(res) < float(cost_dict[res]):
			return false
	return true

## Deducts resources based on a cost dictionary. Returns true if successful.
func spend(cost_dict: Dictionary) -> bool:
	if not can_afford(cost_dict):
		return false
	for res in cost_dict:
		balances[res] -= float(cost_dict[res])
	return true

## Serializes the resource manager state.
func to_dict() -> Dictionary:
	return {
		"balances": balances.duplicate()
	}

## Deserializes and restores the resource manager state.
func from_dict(dict: Dictionary) -> void:
	if dict.has("balances"):
		balances = dict.get("balances", balances).duplicate()
	elif dict.has("resources"):
		balances = dict.get("resources", balances).duplicate()
