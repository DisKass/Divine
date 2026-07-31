class_name ResourceSystem
extends RefCounted

## Zone of Responsibility: Modifying player resource balances in EconomyState. 
## Validates transactions (affordability).

static func init_default_balances(state: GameState) -> void:
	if state.economy.resources.is_empty():
		state.economy.resources["credits"] = 85.0
		state.economy.resources["coal"] = 0.0
		state.economy.resources["iron_ingot"] = 0.0
		state.economy.resources["mana_crystal"] = 0.0
		state.economy.resources["crystal_dust"] = 0.0
		state.economy.resources["crushed_iron"] = 0.0
		state.economy.resources["mana_essence"] = 0.0
		state.economy.resources["runesteel_ingot"] = 0.0

## Adds a resource amount.
static func add_resource(state: GameState, name: String, amount: float) -> void:
	state.economy.resources[name] = state.economy.resources.get(name, 0.0) + amount

## Gets current resource amount.
static func get_resource(state: GameState, name: String) -> float:
	return state.economy.resources.get(name, 0.0)

## Checks if the player can afford a specific dictionary of costs.
## cost_dict is format: {"credits": 50.0, "iron_plate": 10.0}
static func can_afford(state: GameState, cost_dict: Dictionary) -> bool:
	for res in cost_dict:
		if get_resource(state, res) < float(cost_dict[res]):
			return false
	return true

## Deducts resources based on a cost dictionary. Returns true if successful.
static func spend(state: GameState, cost_dict: Dictionary) -> bool:
	if not can_afford(state, cost_dict):
		return false
	for res in cost_dict:
		state.economy.resources[res] -= float(cost_dict[res])
	return true
