class_name ModifierManager
extends RefCounted

## Zone of Responsibility: Centralized calculation of global and local stats.
## Collects bonuses from all sources (Upgrades, Artifacts) and calculates final multipliers (Base * (1 + Increased)).

var sources: Dictionary = {} # source_id (e.g. "artifacts", "upgrades") -> Dictionary of modifier_name -> value

func _init() -> void:
	pass

## Adds or updates a modifier value from a specific source.
func set_source_modifier(source_id: String, modifier_name: String, value: float) -> void:
	if not sources.has(source_id):
		sources[source_id] = {}
	sources[source_id][modifier_name] = value

## Clears all modifiers from a specific source.
func clear_source(source_id: String) -> void:
	if sources.has(source_id):
		sources.erase(source_id)

## Returns the final multiplier for a given modifier. 
## E.g., if total bonus is 0.5, returns 1.5. If no bonus, returns 1.0.
func get_multiplier(modifier_name: String) -> float:
	var total_increased = 0.0
	for source in sources.values():
		total_increased += float(source.get(modifier_name, 0.0))
	return 1.0 + total_increased

## Returns the raw total bonus (e.g., 0.5 for +50%).
func get_bonus(modifier_name: String) -> float:
	var total_bonus = 0.0
	for source in sources.values():
		total_bonus += float(source.get(modifier_name, 0.0))
	return total_bonus
