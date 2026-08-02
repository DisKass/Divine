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

## Generates a new artifact dictionary from a base_id. Does NOT add it to inventory.
static func generate_artifact(base_id: String) -> Dictionary:
	ensure_configs_loaded()
	if not artifact_configs.has(base_id):
		return {}
		
	var config: ArtifactData = artifact_configs[base_id]
	var uid = "item_" + str(Time.get_ticks_usec()) + "_" + str(randi() % 10000)
	
	var item = ItemData.new(uid, base_id)
	item.aoe_size = config.aoe_size
	
	# Apply implicit stats from the base config
	for mod_name in config.implicit_stats:
		item.implicit_stats[mod_name] = float(config.implicit_stats[mod_name])
		
	# In the future, we will roll prefixes and suffixes here.
	return item.to_dict()

## Pushes an existing artifact dictionary into the global inventory.
static func store_artifact_in_vault(state: GameState, item_dict: Dictionary) -> bool:
	if item_dict.is_empty():
		return false
	if state.progress.artifact_inventory.size() >= MAX_INVENTORY_SIZE:
		return false # Inventory is full
		
	state.progress.artifact_inventory.append(item_dict.duplicate(true))
	state.artifact_crafted.emit(item_dict.get("base_id", "unknown"), 1) # Retained for UI updates
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

## Takes an artifact from the UI inventory and puts it into the output buffer of a Vault Gateway (Retrieve).
static func retrieve_artifact_to_vault(state: GameState, item_uid: String, gateway_id: int) -> bool:
	var inventory = state.progress.artifact_inventory
	var item_idx = -1
	for i in range(inventory.size()):
		if inventory[i].get("uid", "") == item_uid:
			item_idx = i
			break
			
	if item_idx == -1:
		return false
		
	var gateway = state.factory.buildings.get(gateway_id)
	if gateway == null or not gateway.is_vault_gateway:
		return false
	
	if gateway.vault_gateway_mode != "retrieve":
		return false
		
	var item = inventory[item_idx]
	var base_id = item.get("base_id", "")
	
	# Only insert if output buffer is empty
	var current_output = gateway.outputs.get(base_id, 0.0)
	if current_output >= 1.0 or not gateway.output_artifact.is_empty():
		return false # Gateway buffer is full, cannot deposit right now
		
	gateway.output_artifact = item.duplicate()
	gateway.outputs[base_id] = current_output + 1.0
	
	inventory.remove_at(item_idx)
	
	gateway.ui_version += 1
	state.artifacts_changed.emit()
	return true

## Permanently destroys an artifact from the UI inventory (used by The Void).
static func destroy_artifact(state: GameState, item_uid: String) -> bool:
	var inventory = state.progress.artifact_inventory
	var item_idx = -1
	for i in range(inventory.size()):
		if inventory[i].get("uid", "") == item_uid:
			item_idx = i
			break
			
	if item_idx == -1:
		return false
		
	inventory.remove_at(item_idx)
	state.artifacts_changed.emit()
	return true
