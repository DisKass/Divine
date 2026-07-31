class_name GameState
extends RefCounted

## Global root state containing all sub-states for the game simulation.

signal milestone_completed(tier: int, milestone_data: Dictionary)
signal milestone_reset()
signal artifacts_changed()
signal artifact_crafted(artifact_id: String, new_count: int)
signal artifact_equipped(slot_idx: int, artifact_id: String)
signal artifact_unequipped(slot_idx: int, artifact_id: String)
signal upgrades_changed()
signal upgrade_purchased(upgrade_id: String, level: int)
signal upgrades_reset()
signal modifiers_changed()
signal template_switched(template_id: String, template_name: String)

var factory: FactoryState
var economy: EconomyState
var progress: ProgressState

# Meta state (Templates)
var templates: Dictionary = {}
var active_template_id: String = "tpl_default"
var free_buildings_mode: bool = false

func _init() -> void:
	factory = FactoryState.new()
	economy = EconomyState.new()
	progress = ProgressState.new()

func to_dict() -> Dictionary:
	var dict = to_snapshot()
	dict["templates"] = templates.duplicate(true)
	dict["active_template_id"] = active_template_id
	dict["free_buildings_mode"] = free_buildings_mode
	return dict

func to_snapshot() -> Dictionary:
	return {
		"factory": factory.to_dict(),
		"economy": economy.to_dict(),
		"progress": progress.to_dict()
	}

static func from_dict(data: Dictionary) -> GameState:
	var state = GameState.new()
	state.load_from_dict(data)
	return state

func load_from_dict(data: Dictionary) -> void:
	load_from_snapshot(data)

	templates = data.get("templates", {}).duplicate(true)
	active_template_id = data.get("active_template_id", "tpl_default")
	free_buildings_mode = data.get("free_buildings_mode", false)

func load_from_snapshot(data: Dictionary) -> void:
	if data.has("factory"):
		factory.load_from_dict(data["factory"])
	if data.has("economy"):
		economy.load_from_dict(data["economy"])
	if data.has("progress"):
		progress.load_from_dict(data["progress"])
