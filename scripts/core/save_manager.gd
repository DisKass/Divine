class_name SaveManager
extends RefCounted

## Handles saving and loading the factory network state and economy state to/from disk.

const SAVE_PATH = "user://factory_save.json"
const SAVE_VERSION = 2

## Saves the simulation state to disk, embedding a Unix timestamp and format version.
static func save_game(network: FactoryNetwork, res_mgr: ResourceManager, build_mgr: BuildingManager, upg_mgr: UpgradesManager, art_mgr: ArtifactsManager, ms_mgr: MilestonesManager) -> bool:
	if network == null or res_mgr == null:
		return false
		
	var save_data = {
		"version": SAVE_VERSION,
		"timestamp": int(Time.get_unix_time_from_system()),
		"network": network.to_dict(),
		"resource_manager": res_mgr.to_dict(),
		"building_manager": build_mgr.to_dict(),
		"upgrades_manager": upg_mgr.to_dict(),
		"artifacts_manager": art_mgr.to_dict(),
		"milestones_manager": ms_mgr.to_dict()
	}
	
	var json_str = JSON.stringify(save_data)
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		printerr("Failed to open save file for writing: ", SAVE_PATH)
		return false
		
	file.store_string(json_str)
	file.close()
	return true

## Loads simulation state from disk.
## Returns a Dictionary with keys "version", "timestamp", "network_dict", and manager dicts, or an empty dictionary if no save exists.
static func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		printerr("Failed to open save file for reading: ", SAVE_PATH)
		return {}
		
	var json_str = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_str)
	if error != OK:
		printerr("Failed to parse save file JSON. Error: ", json.get_error_message())
		return {}
		
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		printerr("Invalid data type in save file.")
		return {}
		
	# Fallback for old save format
	var eco_dict = data.get("economy", {})
	var net_dict = data.get("network", {})
	
	return {
		"version": int(data.get("version", 0)),
		"timestamp": int(data.get("timestamp", 0)),
		"network_dict": net_dict,
		"resource_manager_dict": data.get("resource_manager", eco_dict),
		"building_manager_dict": data.get("building_manager", eco_dict),
		"upgrades_manager_dict": data.get("upgrades_manager", eco_dict),
		"artifacts_manager_dict": data.get("artifacts_manager", eco_dict),
		"milestones_manager_dict": data.get("milestones_manager", eco_dict)
	}



## Deletes the current save game. Useful for testing or resetting progress.
static func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var dir = DirAccess.open("user://")
		if dir:
			dir.remove(SAVE_PATH.get_file())
