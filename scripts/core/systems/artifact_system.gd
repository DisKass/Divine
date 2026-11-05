class_name ArtifactSystem
extends RefCounted

const AffixDb = preload("res://scripts/core/systems/affix_database.gd")


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

## Rolls 3-6 random affixes (tiers, values, building tags) onto a white artifact.
## If artifact already has affixes (>0), returns it unchanged.
static func infuse_artifact(item_dict: Dictionary) -> Dictionary:
	if item_dict.is_empty():
		return {}
		
	var item = ItemData.from_dict(item_dict)
	if not item.is_white():
		return item.to_dict() # Already has affixes, transit as-is
		
	var total_affixes = randi_range(3, 6)
	var available_prefixes: Array[String] = []
	for k in AffixDb.PREFIX_DEFINITIONS:
		available_prefixes.append(k)
		
	var available_suffixes: Array[String] = []
	for k in AffixDb.SUFFIX_DEFINITIONS:
		available_suffixes.append(k)
		
	var prefix_count = 0
	var suffix_count = 0
	
	for i in range(total_affixes):
		var choose_prefix = false
		if prefix_count >= 3 or available_prefixes.is_empty():
			choose_prefix = false
		elif suffix_count >= 3 or available_suffixes.is_empty():
			choose_prefix = true
		else:
			choose_prefix = (randi() % 2 == 0)
			
		if choose_prefix and not available_prefixes.is_empty():
			var idx = randi() % available_prefixes.size()
			var affix_id = available_prefixes[idx]
			available_prefixes.remove_at(idx)
			
			var rolled = AffixDb.roll_affix(affix_id)
			if not rolled.is_empty():
				item.prefixes[affix_id] = rolled
				prefix_count += 1
		elif not available_suffixes.is_empty():
			var idx = randi() % available_suffixes.size()
			var affix_id = available_suffixes[idx]
			available_suffixes.remove_at(idx)
			
			var rolled = AffixDb.roll_affix(affix_id)
			if not rolled.is_empty():
				item.suffixes[affix_id] = rolled
				suffix_count += 1

				
	return item.to_dict()

## Strips all prefixes and suffixes from an artifact, turning it white.
static func purify_artifact(item_dict: Dictionary) -> Dictionary:
	if item_dict.is_empty():
		return {}
		
	var item = ItemData.from_dict(item_dict)
	item.prefixes.clear()
	item.suffixes.clear()
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
	if gateway == null or gateway.type != "vault_gateway":
		return false
	
	if gateway.vault_gateway_mode != "retrieve":
		return false
		
	var item = inventory[item_idx]
	var base_id = item.get("base_id", "")
	
	# Only insert if output buffer is empty
	var slot = gateway.shared_slots[0]
	if not slot.is_empty():
		return false # Gateway buffer is full, cannot deposit right now
		
	var pushed = slot.push(base_id, 1.0, item.duplicate())
	if pushed <= 0.0:
		return false
	
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
