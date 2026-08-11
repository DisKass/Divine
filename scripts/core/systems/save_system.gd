class_name SaveSystem
extends RefCounted

## Handles saving and loading the entire GameState to/from disk.

const SAVE_PATH = "user://factory_save.json"
const SAVE_VERSION = 4

static var _save_thread: Thread = null

static func _thread_save(save_data: Dictionary) -> void:
	var json_str = JSON.stringify(save_data)
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(json_str)
		file.close()
	else:
		printerr("Failed to open save file for writing: ", SAVE_PATH)

## Saves the simulation state to disk, embedding a Unix timestamp and format version.
static func save_game(state: GameState) -> bool:
	if state == null:
		return false

	# Synchronize active snapshot before saving
	TemplateSystem.sync_active_snapshot(state)

	var save_data = {
		"version": SAVE_VERSION,
		"timestamp": int(Time.get_unix_time_from_system()),
		"game_state": state.to_dict()
	}

	if _save_thread != null and _save_thread.is_started():
		_save_thread.wait_to_finish()

	_save_thread = Thread.new()
	_save_thread.start(_thread_save.bind(save_data))

	return true

## Synchronously saves simulation state to disk, waiting for any ongoing async save to complete.
static func save_game_sync(state: GameState) -> bool:
	if state == null:
		return false

	# Synchronize active snapshot before saving
	TemplateSystem.sync_active_snapshot(state)

	var save_data = {
		"version": SAVE_VERSION,
		"timestamp": int(Time.get_unix_time_from_system()),
		"game_state": state.to_dict()
	}

	if _save_thread != null and _save_thread.is_started():
		_save_thread.wait_to_finish()
		_save_thread = null

	_thread_save(save_data)
	return true

## Waits for any active background save thread to finish.
static func wait_save_finished() -> void:
	if _save_thread != null and _save_thread.is_started():
		_save_thread.wait_to_finish()
		_save_thread = null


## Loads simulation state from disk and applies it directly to the provided GameState object.
## If out_metadata dictionary is passed, populates it with save metadata (e.g. timestamp).
## Returns true if load was successful, false otherwise.
static func load_game(state: GameState, out_metadata: Dictionary = {}) -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		printerr("Failed to open save file for reading: ", SAVE_PATH)
		return false

	var json_str = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_str)
	if error != OK:
		printerr("Failed to parse save file JSON. Error: ", json.get_error_message())
		return false

	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		printerr("Invalid data type in save file.")
		return false

	out_metadata["timestamp"] = int(data.get("timestamp", 0))
	out_metadata["version"] = int(data.get("version", 0))

	# For new v4 format
	if data.has("game_state"):
		state.load_from_dict(data["game_state"])
		UpgradeSystem.rebuild_modifiers(state)
		return true


	# Legacy fallback (v3)
	var net_dict = data.get("network", {})
	var res_dict = data.get("resource_manager", {})
	var build_dict = data.get("building_manager", {})
	var upg_dict = data.get("upgrades_manager", {})
	var art_dict = data.get("artifacts_manager", {})
	var ms_dict = data.get("milestones_manager", {})
	var tpl_dict = data.get("template_manager", {})

	# Migrate data into GameState
	if net_dict: state.factory.load_from_dict(net_dict)
	if res_dict: state.economy.load_from_dict(res_dict)

	# building manager data
	if build_dict.has("building_counts"):
		state.factory.building_counts = build_dict["building_counts"].duplicate()

	# upgrades manager data
	if upg_dict.has("upgrades"):
		var raw_upgrades = upg_dict["upgrades"]
		state.progress.unlocked_upgrades.clear()
		for upg_id in raw_upgrades:
			var lvl = int(raw_upgrades[upg_id])
			for i in range(lvl):
				state.progress.unlocked_upgrades.append(upg_id)

	# artifacts manager data
	if art_dict.has("artifact_inventory"):
		state.progress.artifact_inventory = art_dict["artifact_inventory"].duplicate()
	if art_dict.has("equipped_artifacts"):
		var eq = art_dict["equipped_artifacts"]
		for i in range(min(eq.size(), 2)):
			state.progress.equipped_artifacts[i] = String(eq[i])

	# milestones manager data
	if ms_dict.has("current_milestone_index"):
		state.progress.current_milestone_index = int(ms_dict["current_milestone_index"])
	if ms_dict.has("milestone_progress"):
		state.progress.current_milestone_progress = ms_dict["milestone_progress"].duplicate()

	# template manager data
	if tpl_dict.has("templates"):
		state.templates = tpl_dict["templates"].duplicate(true)
	if tpl_dict.has("active_template_id"):
		state.active_template_id = tpl_dict["active_template_id"]

	UpgradeSystem.rebuild_modifiers(state)
	return true

## Deletes the current save game. Useful for testing or resetting progress.
static func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var dir = DirAccess.open("user://")
		if dir:
			dir.remove(SAVE_PATH.get_file())
