class_name ArtifactSystem
extends RefCounted

## Zone of Responsibility: Managing artifact inventory, equipment shift-queue slots, 
## and registering equipped bonuses with ModifierSystem.
## Operates on GameState.

# artifact_id -> ArtifactData (Resource)
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

## Adds crafted artifact to global inventory.
static func add_artifact_to_inventory(state: GameState, artifact_id: String, amount: int = 1) -> void:
	if amount <= 0: return
	var current = int(state.progress.artifact_inventory.get(artifact_id, 0))
	var new_count = current + amount
	state.progress.artifact_inventory[artifact_id] = new_count
	state.artifact_crafted.emit(artifact_id, new_count)
	state.artifacts_changed.emit()

## Equips an artifact using shift/push queue logic.
static func equip_artifact(state: GameState, arg1: Variant, arg2: Variant = null) -> bool:
	ensure_configs_loaded()
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
	var count = int(state.progress.artifact_inventory.get(artifact_id, 0))
	if count <= 0:
		return false

	# Find first free slot
	var free_idx = -1
	for i in range(state.progress.equipped_artifacts.size()):
		if state.progress.equipped_artifacts[i] == "":
			free_idx = i
			break

	if free_idx != -1:
		state.progress.artifact_inventory[artifact_id] = count - 1
		state.progress.equipped_artifacts[free_idx] = artifact_id
		_update_modifiers(state)
		state.artifact_equipped.emit(free_idx, artifact_id)
		state.artifacts_changed.emit()
		return true

	# All slots full: expel last slot to inventory and shift right
	var last_idx = state.progress.equipped_artifacts.size() - 1
	var expelled_id = state.progress.equipped_artifacts[last_idx]
	if expelled_id != "":
		state.progress.artifact_inventory[expelled_id] = int(state.progress.artifact_inventory.get(expelled_id, 0)) + 1
		state.artifact_unequipped.emit(last_idx, expelled_id)

	for i in range(last_idx, 0, -1):
		state.progress.equipped_artifacts[i] = state.progress.equipped_artifacts[i - 1]
		if state.progress.equipped_artifacts[i] != "":
			state.artifact_equipped.emit(i, state.progress.equipped_artifacts[i])

	state.progress.artifact_inventory[artifact_id] = int(state.progress.artifact_inventory.get(artifact_id, 0)) - 1
	state.progress.equipped_artifacts[0] = artifact_id
	_update_modifiers(state)
	state.artifact_equipped.emit(0, artifact_id)
	state.artifacts_changed.emit()
	return true

## Unequips an artifact from slot_idx back into inventory.
static func unequip_artifact(state: GameState, slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= state.progress.equipped_artifacts.size():
		return
	var current_id = state.progress.equipped_artifacts[slot_idx]
	if current_id == "":
		return
	state.progress.equipped_artifacts[slot_idx] = ""
	state.progress.artifact_inventory[current_id] = int(state.progress.artifact_inventory.get(current_id, 0)) + 1
	_update_modifiers(state)
	state.artifact_unequipped.emit(slot_idx, current_id)
	state.artifacts_changed.emit()

static func _update_modifiers(state: GameState) -> void:
	ensure_configs_loaded()
	ModifierSystem.clear_source(state, "artifacts")
	for i in range(state.progress.equipped_artifacts.size()):
		var art_id = state.progress.equipped_artifacts[i]
		if art_id != "" and artifact_configs.has(art_id):
			var config: ArtifactData = artifact_configs[art_id]
			for mod_name in config.modifiers:
				var current_val = state.progress.active_modifiers.get("artifacts", {}).get(mod_name, 0.0)
				ModifierSystem.set_source_modifier(state, "artifacts", mod_name, current_val + float(config.modifiers[mod_name]))
