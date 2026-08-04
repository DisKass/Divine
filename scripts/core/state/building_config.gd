class_name BuildingConfig
extends RefCounted

# Buffer Mode
# "separated" - Distinct input and output slots.
# "shared" - A single shared slot pool used for both inputs and outputs (e.g. Vault).
var buffer_mode: String = "separated"

# Process Logic
# "recipe" - Converts inputs to outputs based on active_recipe.
# "void" - Instantly destroys inputs at the end of the tick.
# "passthrough" - Moves items instantly from input to output (used by splitters).
# "forge_artifact" - Custom logic for artifact creation.
var process_logic: String = "recipe"

# Global Output Link
# If set (e.g. "credits", "portal"), produced items don't go to output slots,
# but are instead submitted to the global milestone/economy system.
var global_output_link: String = ""

# UI overrides
var show_input_slots: bool = true
var show_output_slots: bool = true
var hide_empty_slots: bool = false
var ui_title_override: String = ""

func _init(data: Dictionary = {}):
	buffer_mode = data.get("buffer_mode", "separated")
	process_logic = data.get("process_logic", "recipe")
	global_output_link = data.get("global_output_link", "")
	
	show_input_slots = data.get("show_input_slots", true)
	show_output_slots = data.get("show_output_slots", true)
	hide_empty_slots = data.get("hide_empty_slots", false)
	ui_title_override = data.get("ui_title_override", "")

static func get_default_config_for(building_type: String) -> BuildingConfig:
	var cfg = BuildingConfig.new()
	
	match building_type:
		"the_void":
			cfg.process_logic = "void"
			cfg.show_output_slots = false
		"vault_gateway":
			cfg.buffer_mode = "shared"
			cfg.process_logic = "recipe" # Doesn't actually craft, but holds items
		"portal":
			cfg.process_logic = "recipe"
			cfg.global_output_link = "portal"
			cfg.show_output_slots = false
		"seller":
			cfg.process_logic = "recipe"
			cfg.global_output_link = "credits"
			cfg.show_output_slots = false
		"splitter_2", "splitter_3":
			cfg.process_logic = "passthrough"
			cfg.hide_empty_slots = true
		"miner", "miner_iron", "miner_coal", "miner_crystal":
			cfg.show_input_slots = false
		"artifact_altar":
			cfg.process_logic = "forge_artifact"
			
	return cfg
