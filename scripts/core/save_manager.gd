class_name SaveManager
extends RefCounted

## Handles saving and loading the factory network state and economy state to/from disk.

const SAVE_PATH = "user://factory_save.json"

## Saves the simulation state to disk, embedding a Unix timestamp.
static func save_game(network: FactoryNetwork, economy: EconomyManager) -> bool:
	if network == null or economy == null:
		return false
		
	var save_data = {
		"timestamp": int(Time.get_unix_time_from_system()),
		"network": network.to_dict(),
		"economy": economy.to_dict()
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
## Returns a Dictionary with keys "timestamp", "network_dict", "economy_dict", or an empty dictionary if no save exists.
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
		
	return {
		"timestamp": int(data.get("timestamp", 0)),
		"network_dict": data.get("network", {}),
		"economy_dict": data.get("economy", {})
	}

## Deletes the current save game. Useful for testing or resetting progress.
static func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var dir = DirAccess.open("user://")
		if dir:
			dir.remove(SAVE_PATH.get_file())
