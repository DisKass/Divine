class_name UpgradeSystem
extends RefCounted

## Zone of Responsibility: Managing global upgrades progression and registering their bonuses with ModifierSystem.
## Operates on GameState.

# upgrade_id -> UpgradeData (Resource)
static var upgrade_configs: Dictionary = {}
static var configs_loaded: bool = false

static func ensure_configs_loaded() -> void:
	if configs_loaded:
		return
	var types = ["miner_speed", "factory_speed", "logistics_transfer"]
	for type in types:
		var path = "res://data/upgrades/" + type + ".tres"
		if ResourceLoader.exists(path):
			upgrade_configs[type] = ResourceLoader.load(path)
	configs_loaded = true

## Resets all purchased upgrades back to level 0 and clears their modifiers.
static func reset_upgrades(state: GameState) -> void:
	ensure_configs_loaded()
	for id in upgrade_configs.keys():
		ModifierSystem.clear_source(state, "upgrades_" + id)
	state.progress.unlocked_upgrades.clear()
	rebuild_modifiers(state)
	state.upgrades_reset.emit()

## Returns the purchased level for an upgrade.
static func get_upgrade_level(state: GameState, id: String) -> int:
	# In ProgressState unlocked_upgrades is currently an array of strings, 
	# but wait, the old upgrades_manager used a dictionary (id -> level).
	# Let's fix ProgressState to use a Dictionary for upgrades or count them.
	# Let's just count occurrences in the array, or better yet, we'll assume it's a list and we count how many times it appears.
	var count = 0
	for u in state.progress.unlocked_upgrades:
		if u == id:
			count += 1
	return count

## Returns cost dictionary for the next level of an upgrade.
static func get_upgrade_cost(state: GameState, id: String) -> Dictionary:
	ensure_configs_loaded()
	if not upgrade_configs.has(id): return {}
	var config: UpgradeData = upgrade_configs[id]
	var lvl = get_upgrade_level(state, id)

	if lvl >= config.max_level:
		return {} # Max level reached

	var cost_val = snappedf(config.base_cost * pow(config.cost_multiplier, lvl), 0.1)
	return { "credits": cost_val }

## Checks if player can afford the next level of upgrade.
static func can_afford_upgrade(state: GameState, id: String) -> bool:
	var cost = get_upgrade_cost(state, id)
	if cost.is_empty():
		return false
	return ResourceSystem.can_afford(state, cost)

## Buys the next level of upgrade if affordable. Returns true if successful.
static func buy_upgrade(state: GameState, id: String) -> bool:
	if not can_afford_upgrade(state, id):
		return false
	var cost = get_upgrade_cost(state, id)
	if ResourceSystem.spend(state, cost):
		state.progress.unlocked_upgrades.append(id)
		var new_lvl = get_upgrade_level(state, id)

		# Register with modifier system
		_update_modifiers(state, id)

		state.upgrade_purchased.emit(id, new_lvl)
		state.upgrades_changed.emit()
		return true
	return false

static func _update_modifiers(state: GameState, id: String) -> void:
	ensure_configs_loaded()
	if not upgrade_configs.has(id): return
	var config: UpgradeData = upgrade_configs[id]
	var lvl = get_upgrade_level(state, id)
	var bonus = lvl * config.bonus_per_level
	ModifierSystem.set_source_modifier(state, "upgrades_" + id, id, bonus)

## Recalculates all active modifiers (useful after loading save).
static func rebuild_modifiers(state: GameState) -> void:
	ensure_configs_loaded()
	var unique_upgrades = {}
	for id in state.progress.unlocked_upgrades:
		unique_upgrades[id] = true
	for id in unique_upgrades:
		_update_modifiers(state, id)
