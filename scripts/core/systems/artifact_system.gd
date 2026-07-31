class_name ArtifactSystem
extends RefCounted

## Zone of Responsibility: Managing artifact inventory, item rolling, and altar slotting.
## Operates on GameState.

const MAX_INVENTORY_SIZE = 5

const PREFIX_POOL = [
	{"name": "factory_speed", "value": 0.1, "desc": "+10% Factory Speed"},
	{"name": "production_flat", "value": 1.0, "desc": "+1 Flat Production"},
	{"name": "acceleration_cont", "value": 0.05, "desc": "+5% Acceleration (Continuous)"},
	{"name": "acceleration_inter", "value": 0.05, "desc": "+5% Acceleration (Interrupted)"},
	{"name": "crit_craft_chance", "value": 0.1, "desc": "+10% Crit Craft Chance"}
]

const SUFFIX_POOL = [
	{"name": "double_craft_chance", "value": 0.1, "desc": "+10% Double Craft Chance"},
	{"name": "extra_flat_chance", "value": 0.1, "desc": "+10% Extra Flat Chance"},
	{"name": "save_input_chance", "value": 0.1, "desc": "+10% Save Input Chance"},
	{"name": "sell_multiplier", "value": 0.2, "desc": "+20% Sell Value"},
	{"name": "aoe_bonus", "value": 1.0, "desc": "+1 AoE Radius"}
]

# base_id -> ArtifactData (Resource)
static var artifact_configs: Dictionary = {}
static var configs_loaded: bool = false

static func ensure_configs_loaded() -> void:
	if configs_loaded:
		return
	var types = ["runesteel_amulet", "ring_of_wealth", "philosophers_stone"]
	for type in types:
		var path = "res://data/artifacts/" + type + ".tres"
		if ResourceLoader.exists(path):
			artifact_configs[type] = ResourceLoader.load(path)
	configs_loaded = true

## Attempts to add a new artifact base to the inventory. Returns true if successful.
static func add_artifact_base_to_inventory(state: GameState, base_id: String) -> bool:
	ensure_configs_loaded()
	if not artifact_configs.has(base_id):
		return false
	
	if state.progress.artifact_inventory.size() >= MAX_INVENTORY_SIZE:
		return false # Inventory is full
		
	var config: ArtifactData = artifact_configs[base_id]
	var uid = "item_" + str(Time.get_ticks_usec()) + "_" + str(randi() % 10000)
	
	var item = ItemData.new(uid, base_id)
	item.aoe_size = config.aoe_size
	
	# Apply implicit stats from the base config
	for mod_name in config.implicit_stats:
		item.implicit_stats[mod_name] = float(config.implicit_stats[mod_name])
		
	# In the future, we will roll prefixes and suffixes here.
	
	state.progress.artifact_inventory.append(item.to_dict())
	state.artifact_crafted.emit(base_id, 1) # Retained for UI updates
	state.artifacts_changed.emit()
	return true

## Equips an artifact from the inventory into a specific Altar.
static func equip_artifact_to_altar(state: GameState, item_uid: String, altar_id: int) -> bool:
	var inventory = state.progress.artifact_inventory
	var item_idx = -1
	for i in range(inventory.size()):
		if inventory[i].get("uid", "") == item_uid:
			item_idx = i
			break
			
	if item_idx == -1:
		return false
		
	var altar = state.factory.buildings.get(altar_id)
	if altar == null or altar.type != "artifact_altar":
		return false
		
	# If altar already has an item, try to swap it back
	if not altar.held_artifact.is_empty():
		# Temporarily store the old artifact
		var old_artifact = altar.held_artifact.duplicate()
		altar.held_artifact = inventory[item_idx].duplicate()
		inventory[item_idx] = old_artifact
	else:
		altar.held_artifact = inventory[item_idx].duplicate()
		inventory.remove_at(item_idx)
		
	altar.ui_version += 1
	state.artifacts_changed.emit()
	return true

## Removes an artifact from an Altar and puts it back in the inventory.
static func unequip_artifact_from_altar(state: GameState, altar_id: int) -> bool:
	var altar = state.factory.buildings.get(altar_id)
	if altar == null or altar.type != "artifact_altar":
		return false
		
	if altar.held_artifact.is_empty():
		return false
		
	if state.progress.artifact_inventory.size() >= MAX_INVENTORY_SIZE:
		return false # Cannot unequip if inventory is full
		
	state.progress.artifact_inventory.append(altar.held_artifact.duplicate())
	altar.held_artifact.clear()
	
	altar.ui_version += 1
	state.artifacts_changed.emit()
	return true
