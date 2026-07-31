class_name ProgressState
extends RefCounted

## Stores progression data (upgrades, artifacts, milestones, modifiers).

var unlocked_upgrades: Array[String] = []
var active_modifiers: Dictionary = {}
var artifact_inventory: Dictionary = {}
var equipped_artifacts: Array[String] = ["", ""]
var current_milestone_index: int = 0
var current_milestone_progress: Dictionary = {}
var completed_milestones: Array[String] = []

func to_dict() -> Dictionary:
	return {
		"unlocked_upgrades": unlocked_upgrades.duplicate(),
		"active_modifiers": active_modifiers.duplicate(),
		"artifact_inventory": artifact_inventory.duplicate(),
		"equipped_artifacts": equipped_artifacts.duplicate(),
		"current_milestone_index": current_milestone_index,
		"current_milestone_progress": current_milestone_progress.duplicate(),
		"completed_milestones": completed_milestones.duplicate()
	}

static func from_dict(data: Dictionary) -> ProgressState:
	var state = ProgressState.new()
	state.load_from_dict(data)
	return state

func load_from_dict(data: Dictionary) -> void:
	var loaded_upgrades = data.get("unlocked_upgrades", [])
	unlocked_upgrades.clear()
	for u in loaded_upgrades:
		unlocked_upgrades.append(u)

	active_modifiers = data.get("active_modifiers", {}).duplicate()
	artifact_inventory = data.get("artifact_inventory", {}).duplicate()

	var saved_eq = data.get("equipped_artifacts", ["", ""])
	equipped_artifacts = ["", ""]
	for i in range(min(saved_eq.size(), 2)):
		equipped_artifacts[i] = String(saved_eq[i])

	current_milestone_index = int(data.get("current_milestone_index", 0))
	current_milestone_progress = data.get("current_milestone_progress", {}).duplicate()

	var loaded_milestones = data.get("completed_milestones", [])
	completed_milestones.clear()
	for m in loaded_milestones:
		completed_milestones.append(m)
