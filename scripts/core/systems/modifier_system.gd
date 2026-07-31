class_name ModifierSystem
extends RefCounted

## Zone of Responsibility: Centralized calculation of global and local stats.
## Collects bonuses from all sources (Upgrades, Artifacts) and calculates final multipliers (Base * (1 + Increased)).
## Operates on GameState (progress.active_modifiers).

## Adds or updates a modifier value from a specific source.
static func set_source_modifier(state: GameState, source_id: String, modifier_name: String, value: float) -> void:
	if not state.progress.active_modifiers.has(source_id):
		state.progress.active_modifiers[source_id] = {}
	state.progress.active_modifiers[source_id][modifier_name] = value
	state.modifiers_changed.emit()

## Clears all modifiers from a specific source.
static func clear_source(state: GameState, source_id: String) -> void:
	if state.progress.active_modifiers.has(source_id):
		state.progress.active_modifiers.erase(source_id)
		state.modifiers_changed.emit()

## Returns the final multiplier for a given modifier. 
## E.g., if total bonus is 0.5, returns 1.5. If no bonus, returns 1.0.
static func get_multiplier(state: GameState, modifier_name: String, building: BuildingData = null) -> float:
	return 1.0 + get_bonus(state, modifier_name, building)

## Returns the raw total bonus (e.g., 0.5 for +50%).
static func get_bonus(state: GameState, modifier_name: String, building: BuildingData = null) -> float:
	var total_bonus = 0.0
	for source in state.progress.active_modifiers.values():
		total_bonus += float(source.get(modifier_name, 0.0))
		
	if building != null:
		var target_rect = Rect2i(building.grid_position, building.size_in_cells)
		for altar in state.factory.altars:
			if not altar.held_artifact.is_empty():
				var item = ItemData.from_dict(altar.held_artifact)
				var aoe = item.aoe_size
				var altar_rect = Rect2i(altar.grid_position - Vector2i(aoe, aoe), altar.size_in_cells + Vector2i(aoe * 2, aoe * 2))
				
				if altar_rect.intersects(target_rect):
					total_bonus += item.get_modifier_total(modifier_name)
					
	return total_bonus
