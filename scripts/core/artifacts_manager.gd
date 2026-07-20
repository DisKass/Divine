class_name ArtifactsManager
extends RefCounted

## Zone of Responsibility: Managing artifact inventory, equipment shift-queue slots, 
## and registering equipped bonuses with ModifierManager.

signal artifact_crafted(artifact_id: String, new_count: int)
signal artifact_equipped(slot_idx: int, artifact_id: String)
signal artifact_unequipped(slot_idx: int, artifact_id: String)

var modifier_manager: ModifierManager

var artifact_inventory: Dictionary = {} # artifact_id -> count (int)
var equipped_artifacts: Array[String] = ["", ""]

var artifact_configs: Dictionary = {} # artifact_id -> ArtifactData (Resource)

func _init(mod_mgr: ModifierManager) -> void:
	modifier_manager = mod_mgr
	_load_configs()

func _load_configs() -> void:
	var types = ["runesteel_amulet", "ring_of_wealth", "philosophers_stone"]
	for type in types:
		var path = "res://data/artifacts/" + type + ".tres"
		if ResourceLoader.exists(path):
			artifact_configs[type] = ResourceLoader.load(path)

## Adds crafted artifact to global inventory.
func add_artifact_to_inventory(artifact_id: String, amount: int = 1) -> void:
	if amount <= 0: return
	var current = int(artifact_inventory.get(artifact_id, 0))
	var new_count = current + amount
	artifact_inventory[artifact_id] = new_count
	artifact_crafted.emit(artifact_id, new_count)

## Equips an artifact using shift/push queue logic.
func equip_artifact(arg1: Variant, arg2: Variant = null) -> bool:
	var artifact_id: String = ""
	var _requested_slot: int = -1 # Used if user specifically selected a slot, optional
	
	if arg1 is int and arg2 is String:
		_requested_slot = int(arg1)
		artifact_id = String(arg2)
	elif arg1 is String:
		artifact_id = String(arg1)
		if arg2 is int:
			_requested_slot = int(arg2)
			
	if not artifact_configs.has(artifact_id):
		return false
	var count = int(artifact_inventory.get(artifact_id, 0))
	if count <= 0:
		return false
		
	# Find first free slot
	var free_idx = -1
	for i in range(equipped_artifacts.size()):
		if equipped_artifacts[i] == "":
			free_idx = i
			break
			
	if free_idx != -1:
		artifact_inventory[artifact_id] = count - 1
		equipped_artifacts[free_idx] = artifact_id
		_update_modifiers()
		artifact_equipped.emit(free_idx, artifact_id)
		return true
		
	# All slots full: expel last slot to inventory and shift right
	var last_idx = equipped_artifacts.size() - 1
	var expelled_id = equipped_artifacts[last_idx]
	if expelled_id != "":
		artifact_inventory[expelled_id] = int(artifact_inventory.get(expelled_id, 0)) + 1
		artifact_unequipped.emit(last_idx, expelled_id)
		
	for i in range(last_idx, 0, -1):
		equipped_artifacts[i] = equipped_artifacts[i - 1]
		if equipped_artifacts[i] != "":
			artifact_equipped.emit(i, equipped_artifacts[i])
			
	artifact_inventory[artifact_id] = int(artifact_inventory.get(artifact_id, 0)) - 1
	equipped_artifacts[0] = artifact_id
	_update_modifiers()
	artifact_equipped.emit(0, artifact_id)
	return true

## Unequips an artifact from slot_idx back into inventory.
func unequip_artifact(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= equipped_artifacts.size():
		return
	var current_id = equipped_artifacts[slot_idx]
	if current_id == "":
		return
	equipped_artifacts[slot_idx] = ""
	artifact_inventory[current_id] = int(artifact_inventory.get(current_id, 0)) + 1
	_update_modifiers()
	artifact_unequipped.emit(slot_idx, current_id)

func _update_modifiers() -> void:
	modifier_manager.clear_source("artifacts")
	for i in range(equipped_artifacts.size()):
		var art_id = equipped_artifacts[i]
		if art_id != "" and artifact_configs.has(art_id):
			var config: ArtifactData = artifact_configs[art_id]
			for mod_name in config.modifiers:
				var current_val = modifier_manager.sources.get("artifacts", {}).get(mod_name, 0.0)
				modifier_manager.set_source_modifier("artifacts", mod_name, current_val + float(config.modifiers[mod_name]))

## Serializes the artifacts manager state.
func to_dict() -> Dictionary:
	return {
		"artifact_inventory": artifact_inventory.duplicate(),
		"equipped_artifacts": equipped_artifacts.duplicate()
	}

## Deserializes and restores the artifacts manager state.
func from_dict(dict: Dictionary) -> void:
	artifact_inventory = dict.get("artifact_inventory", {}).duplicate()
	var saved_eq = dict.get("equipped_artifacts", ["", ""])
	equipped_artifacts = ["", ""]
	for i in range(min(saved_eq.size(), 2)):
		equipped_artifacts[i] = String(saved_eq[i])
	_update_modifiers()
