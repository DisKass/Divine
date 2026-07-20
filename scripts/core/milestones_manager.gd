class_name MilestonesManager
extends RefCounted

## Zone of Responsibility: Tracking milestone completion, managing portal deliveries, and determining current game tier.

signal milestone_completed(tier: int, milestone_data: Dictionary)

var current_milestone_index: int = 0
var milestone_progress: Dictionary = {}

var milestones: Array[MilestoneData] = []

func _init() -> void:
	_load_configs()

func _load_configs() -> void:
	for i in range(1, 4): # Tiers 1-3
		var path = "res://data/milestones/tier_" + str(i) + ".tres"
		if ResourceLoader.exists(path):
			milestones.append(ResourceLoader.load(path))

## Returns player's current unlocked tier index (1-based).
func get_current_tier() -> int:
	return current_milestone_index + 1

## Submits delivered resources from Portal and checks for milestone completion.
func submit_portal_resource(res_name: String, amount: float) -> void:
	if current_milestone_index >= milestones.size():
		return # All milestones completed
		
	var active_m: MilestoneData = milestones[current_milestone_index]
	
	if active_m.requirements.has(res_name):
		var target = float(active_m.requirements[res_name])
		var current = milestone_progress.get(res_name, 0.0)
		var space = maxf(target - current, 0.0)
		var added = minf(amount, space)
		if added > 0.0:
			milestone_progress[res_name] = current + added
			check_milestone_completion()

## Checks if active milestone is fulfilled and advances to next.
func check_milestone_completion() -> void:
	if current_milestone_index >= milestones.size():
		return
		
	var active_m: MilestoneData = milestones[current_milestone_index]
	var is_fulfilled = true
	for res in active_m.requirements:
		if milestone_progress.get(res, 0.0) < float(active_m.requirements[res]):
			is_fulfilled = false
			break
			
	if is_fulfilled:
		var tier_val = active_m.tier
		var dict_data = {
			"tier": tier_val,
			"name": active_m.name,
			"requirements": active_m.requirements.duplicate()
		}
		current_milestone_index += 1
		milestone_progress.clear()
		milestone_completed.emit(tier_val, dict_data)

## Returns info on active milestone and progress.
func get_current_milestone() -> Dictionary:
	if current_milestone_index >= milestones.size():
		return {
			"completed_all": true,
			"tier": milestones.size(),
			"name": "All Milestones Completed",
			"requirements": {},
			"progress": {}
		}
	var active_m: MilestoneData = milestones[current_milestone_index]
	return {
		"completed_all": false,
		"tier": active_m.tier,
		"name": active_m.name,
		"requirements": active_m.requirements.duplicate(),
		"progress": milestone_progress.duplicate()
	}

## Serializes the milestones manager state.
func to_dict() -> Dictionary:
	return {
		"current_milestone_index": current_milestone_index,
		"milestone_progress": milestone_progress.duplicate()
	}

## Deserializes and restores the milestones manager state.
func from_dict(dict: Dictionary) -> void:
	current_milestone_index = int(dict.get("current_milestone_index", 0))
	milestone_progress = dict.get("milestone_progress", {}).duplicate()
