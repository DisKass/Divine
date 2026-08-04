class_name BuildingData
extends RefCounted

## Represents a building instance in the factory simulation.
## Decoupled from Godot's visual representation for high-performance tick execution.

const DEFAULT_SIZES: Dictionary = {
	"miner": Vector2i(2, 2),
	"smelter": Vector2i(3, 2),
	"converter": Vector2i(3, 2),
	"assembler": Vector2i(3, 3),
	"extractor": Vector2i(3, 2),
	"infuser": Vector2i(3, 3),
	"portal": Vector2i(3, 3),
	"seller": Vector2i(2, 2),
	"splitter_2": Vector2i(1, 2),
	"splitter_3": Vector2i(1, 2),
	# Backwards compatibility
	"miner_iron": Vector2i(2, 2),
	"miner_coal": Vector2i(2, 2),
	"miner_crystal": Vector2i(2, 2),
	"crusher": Vector2i(3, 2),
	"constructor": Vector2i(3, 2),
	"alchemy_lab": Vector2i(3, 3),
	"artifact_altar": Vector2i(4, 4),
	"shell_forge": Vector2i(3, 3),
	"vault_gateway": Vector2i(3, 3),
	"the_void": Vector2i(3, 3)
}

static func get_default_size(building_type: String) -> Vector2i:
	return DEFAULT_SIZES.get(building_type, Vector2i(3, 2))

static func get_output_ports_count(building_type: String, recipe_data: Dictionary = {}) -> int:
	var cfg = BuildingConfig.get_default_config_for(building_type)
	if not cfg.show_output_slots:
		return 0
	if building_type == "vault_gateway":
		if recipe_data.get("vault_gateway_mode", "store") == "retrieve":
			return 1
		return 0
	if building_type == "splitter_2": return 2
	if building_type == "splitter_3": return 3
	
	var outputs_dictionary = recipe_data.get("outputs", {})
	var real_count = 0
	for resource_key in outputs_dictionary:
		if not str(resource_key).begins_with("_"):
			real_count += 1
	return max(1, real_count)

static func get_input_ports_count(building_type: String, recipe_data: Dictionary = {}) -> int:
	var cfg = BuildingConfig.get_default_config_for(building_type)
	if not cfg.show_input_slots:
		return 0
	if building_type == "vault_gateway":
		if recipe_data.get("vault_gateway_mode", "store") == "retrieve":
			return 0
		return 1
	if building_type in ["assembler", "infuser"]:
		var inputs_dictionary = recipe_data.get("inputs", {})
		var real_count = 0
		for resource_key in inputs_dictionary:
			if not str(resource_key).begins_with("_"):
				real_count += 1
		return max(2, real_count)
	
	var inputs_dictionary = recipe_data.get("inputs", {})
	var real_count = 0
	for resource_key in inputs_dictionary:
		if not str(resource_key).begins_with("_"):
			real_count += 1
	return max(1, real_count)

var id: int
var type: String
var grid_position: Vector2i
var size_in_cells: Vector2i = Vector2i(4, 2)
var last_outgoing_connection_index: int = 0

var vault_gateway_mode: String = "store"

# UI Dirty Tracker
var ui_version: int = 0

# Configuration
var config: BuildingConfig

# New Buffers
var input_slots: Array[ItemSlot] = []
var output_slots: Array[ItemSlot] = []
var shared_slots: Array[ItemSlot] = []

# Active production recipe
var active_recipe: Dictionary = {}
var production_progress: float = 0.0
var is_producing: bool = false
var _cached_duration: float = 1.0

# Special variables
var held_artifact: Dictionary = {}

func _init(building_id: int, building_type: String, grid_pos: Vector2i, recipe_data: Dictionary = {}, size_cells: Vector2i = Vector2i.ZERO) -> void:
	id = building_id
	type = building_type
	grid_position = grid_pos
	active_recipe = recipe_data
	size_in_cells = size_cells if size_cells != Vector2i.ZERO else get_default_size(building_type)
	config = BuildingConfig.get_default_config_for(building_type)

	_update_recipe_cache()

func _update_recipe_cache() -> void:
	_cached_duration = float(active_recipe.get("duration", 1.0))
	
	input_slots.clear()
	output_slots.clear()
	
	if config.buffer_mode != "shared":
		shared_slots.clear()

	var _cached_recipe_inputs = active_recipe.get("inputs", {})
	var _cached_recipe_outputs = active_recipe.get("outputs", {})
	
	var cap_multiplier = 10.0
	var default_limit = 20.0
	
	if type == "vault_gateway":
		cap_multiplier = 1.0
		default_limit = 1.0
		if shared_slots.is_empty():
			var slot = ItemSlot.new(["<artifact>"], default_limit)
			shared_slots.append(slot)
		
		# Assign references depending on mode
		if vault_gateway_mode == "store":
			input_slots.append(shared_slots[0])
		else:
			output_slots.append(shared_slots[0])
	else:
		if config.buffer_mode == "separated":
			if config.show_input_slots:
				for resource_name in _cached_recipe_inputs:
					if not str(resource_name).begins_with("_"):
						var limit = maxf(float(_cached_recipe_inputs[resource_name]) * cap_multiplier, default_limit)
						input_slots.append(ItemSlot.new([resource_name], limit))
						
			if config.show_output_slots:
				for resource_name in _cached_recipe_outputs:
					if not str(resource_name).begins_with("_"):
						var limit = maxf(float(_cached_recipe_outputs[resource_name]) * cap_multiplier, default_limit)
						if type == "shell_forge":
							limit = 1.0
						output_slots.append(ItemSlot.new([resource_name], limit))
						
			if config.process_logic == "passthrough":
				# Splitter needs an input slot but it's empty tags
				input_slots.append(ItemSlot.new([], 20.0))

	ui_version += 1

## Returns all grid cell coordinates occupied by this building.
func get_occupied_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(size_in_cells.x):
		for y in range(size_in_cells.y):
			cells.append(grid_position + Vector2i(x, y))
	return cells

## Changes the active recipe of the building, resetting production progress and buffers.
func set_recipe(new_recipe_data: Dictionary) -> void:
	active_recipe = new_recipe_data.duplicate(true)
	production_progress = 0.0
	is_producing = false
	_update_recipe_cache()

## Returns the number of physical ports the building has (used for link validation).
func get_port_count(is_output: bool) -> int:
	if type.begins_with("splitter"):
		if is_output:
			return BuildingData.get_output_ports_count(type)
		else:
			return BuildingData.get_input_ports_count(type)
	if is_output:
		return output_slots.size()
	else:
		return input_slots.size()

## Returns the ItemSlot corresponding to the physical port index.
func get_port_slot(is_output: bool, port_idx: int) -> ItemSlot:
	if type.begins_with("splitter"):
		# Splitters only have 1 logical input slot and 0 logical output slots (passthrough)
		if not is_output and input_slots.size() > 0:
			return input_slots[0]
		return null
		
	var target_array = output_slots if is_output else input_slots
	if config.buffer_mode == "shared":
		if type == "vault_gateway":
			# Vault gateway uses shared_slots[0] for either input (store) or output (retrieve)
			if (vault_gateway_mode == "store" and not is_output) or (vault_gateway_mode == "retrieve" and is_output):
				if shared_slots.size() > 0:
					return shared_slots[0]
			return null
		target_array = shared_slots
		
	if port_idx >= 0 and port_idx < target_array.size():
		return target_array[port_idx]
	return null


## Serializes building data state to dictionary.
func to_dict() -> Dictionary:
	var input_slots_data = []
	for slot in input_slots:
		input_slots_data.append(slot.to_dict())
		
	var output_slots_data = []
	for slot in output_slots:
		output_slots_data.append(slot.to_dict())
		
	var shared_slots_data = []
	for slot in shared_slots:
		shared_slots_data.append(slot.to_dict())
		
	return {
		"id": id,
		"type": type,
		"grid_position": [grid_position.x, grid_position.y],
		"size_in_cells": [size_in_cells.x, size_in_cells.y],
		"input_slots": input_slots_data,
		"output_slots": output_slots_data,
		"shared_slots": shared_slots_data,
		"active_recipe": active_recipe.duplicate(),
		"production_progress": production_progress,
		"is_producing": is_producing,
		"vault_gateway_mode": vault_gateway_mode,
		"held_artifact": held_artifact.duplicate()
	}

## Deserializes building data state from dictionary.
static func from_dict(data_dictionary: Dictionary) -> BuildingData:
	var parsed_position = Vector2i(int(data_dictionary["grid_position"][0]), int(data_dictionary["grid_position"][1]))
	var parsed_recipe = data_dictionary.get("active_recipe", {}).duplicate()
	var parsed_size = get_default_size(data_dictionary.get("type", ""))

	var building_instance = BuildingData.new(int(data_dictionary["id"]), data_dictionary["type"], parsed_position, parsed_recipe, parsed_size)
	
	building_instance.production_progress = data_dictionary.get("production_progress", 0.0)
	building_instance.is_producing = data_dictionary.get("is_producing", false)
	building_instance.vault_gateway_mode = data_dictionary.get("vault_gateway_mode", "store")
	building_instance.held_artifact = data_dictionary.get("held_artifact", {}).duplicate()
	
	# After _init, slots are created based on recipe. We load amounts into them.
	var in_slots_data = data_dictionary.get("input_slots", [])
	for i in range(min(in_slots_data.size(), building_instance.input_slots.size())):
		building_instance.input_slots[i].load_from_dict(in_slots_data[i])
		
	var out_slots_data = data_dictionary.get("output_slots", [])
	for i in range(min(out_slots_data.size(), building_instance.output_slots.size())):
		building_instance.output_slots[i].load_from_dict(out_slots_data[i])
		
	var shared_slots_data = data_dictionary.get("shared_slots", [])
	for i in range(min(shared_slots_data.size(), building_instance.shared_slots.size())):
		building_instance.shared_slots[i].load_from_dict(shared_slots_data[i])

	return building_instance
