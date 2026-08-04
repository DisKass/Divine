class_name MilestoneSystem
extends RefCounted

## Zone of Responsibility: Tracking milestone completion, managing portal deliveries, and determining current game tier.
## Operates on GameState.

static var milestones: Array[MilestoneData] = []
static var configs_loaded: bool = false

static func ensure_configs_loaded() -> void:
	if configs_loaded:
		return
	for i in range(1, 4): # Tiers 1-3
		var path = "res://data/milestones/tier_" + str(i) + ".tres"
		if ResourceLoader.exists(path):
			milestones.append(ResourceLoader.load(path))
	configs_loaded = true

## Resets milestone progression back to Tier 1.
static func reset_milestone_progress(state: GameState) -> void:
	state.progress.current_milestone_index = 0
	state.progress.current_milestone_progress.clear()
	state.milestone_reset.emit()

## Returns player's current unlocked tier index (1-based).
static func get_current_tier(state: GameState) -> int:
	return state.progress.current_milestone_index + 1

## Submits delivered resources from Portal and checks for milestone completion.
static func submit_portal_resource(state: GameState, res_name: String, amount: float) -> void:
	ensure_configs_loaded()
	if state.progress.current_milestone_index >= milestones.size():
		return # All milestones completed

	var active_m: MilestoneData = milestones[state.progress.current_milestone_index]

	if active_m.requirements.has(res_name):
		var target = float(active_m.requirements[res_name])
		var current = float(state.progress.current_milestone_progress.get(res_name, 0.0))
		state.progress.current_milestone_progress[res_name] = minf(current + amount, target)
		check_milestone_completion(state)

## Checks if active milestone is fulfilled and advances to next.
static func check_milestone_completion(state: GameState) -> void:
	ensure_configs_loaded()
	if state.progress.current_milestone_index >= milestones.size():
		return

	var active_m: MilestoneData = milestones[state.progress.current_milestone_index]
	var is_fulfilled = true
	for res in active_m.requirements:
		if state.progress.current_milestone_progress.get(res, 0.0) < float(active_m.requirements[res]):
			is_fulfilled = false
			break

	if is_fulfilled:
		var tier_val = active_m.tier
		var dict_data = {
			"tier": tier_val,
			"name": active_m.name,
			"requirements": active_m.requirements.duplicate()
		}
		state.progress.completed_milestones.append(active_m.name)
		state.progress.current_milestone_index += 1
		state.progress.current_milestone_progress.clear()
		state.milestone_completed.emit(tier_val, dict_data)

## Returns info on active milestone and progress.
static func get_current_milestone(state: GameState) -> Dictionary:
	ensure_configs_loaded()
	if state.progress.current_milestone_index >= milestones.size():
		return {
			"completed_all": true,
			"tier": milestones.size(),
			"name": "All Milestones Completed",
			"requirements": {},
			"progress": {}
		}
	var active_m: MilestoneData = milestones[state.progress.current_milestone_index]
	return {
		"completed_all": false,
		"tier": active_m.tier,
		"name": active_m.name,
		"requirements": active_m.requirements.duplicate(),
		"progress": state.progress.current_milestone_progress.duplicate()
	}
