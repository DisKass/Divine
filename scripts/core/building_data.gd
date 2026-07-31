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
	"artifact_altar": Vector2i(3, 3)
}

static func get_default_size(building_type: String) -> Vector2i:
	return DEFAULT_SIZES.get(building_type, Vector2i(3, 2))

static func get_output_ports_count(building_type: String, recipe_data: Dictionary = {}) -> int:
	match building_type:
		"splitter_2": return 2
		"splitter_3": return 3
		"portal", "seller": return 0
		_:
			var outputs_dictionary = recipe_data.get("outputs", {})
			var real_count = 0
			for resource_key in outputs_dictionary:
				if not str(resource_key).begins_with("_"):
					real_count += 1
			return max(1, real_count)

static func get_input_ports_count(building_type: String, recipe_data: Dictionary = {}) -> int:
	match building_type:
		"miner": return 0
		"assembler", "infuser":
			var inputs_dictionary = recipe_data.get("inputs", {})
			var real_count = 0
			for resource_key in inputs_dictionary:
				if not str(resource_key).begins_with("_"):
					real_count += 1
			return max(2, real_count)
		_:
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

# Fast cached type flags
var is_splitter: bool = false
var is_portal: bool = false
var is_miner: bool = false
var is_seller: bool = false

# Cached recipe fields
var _cached_recipe_inputs: Dictionary = {}
var _cached_recipe_outputs: Dictionary = {}
var _cached_duration: float = 1.0

# UI Dirty Tracker
var ui_version: int = 0

# Buffers: resource_name (String) -> amount (float)
var inputs: Dictionary = {}
var input_limits: Dictionary = {}
var outputs: Dictionary = {}
var output_limits: Dictionary = {}

# Active production recipe
var active_recipe: Dictionary = {}
var production_progress: float = 0.0
var is_producing: bool = false

func _init(building_id: int, building_type: String, grid_pos: Vector2i, recipe_data: Dictionary = {}, size_cells: Vector2i = Vector2i.ZERO) -> void:
	id = building_id
	type = building_type
	grid_position = grid_pos
	active_recipe = recipe_data
	size_in_cells = size_cells if size_cells != Vector2i.ZERO else get_default_size(building_type)

	is_splitter = type.begins_with("splitter")
	is_portal = (type == "portal")
	is_miner = type.begins_with("miner")
	is_seller = type.begins_with("seller")

	_update_recipe_cache()

func _update_recipe_cache() -> void:
	_cached_recipe_inputs = active_recipe.get("inputs", {})
	_cached_recipe_outputs = active_recipe.get("outputs", {})
	_cached_duration = float(active_recipe.get("duration", 1.0))

	inputs.clear()
	outputs.clear()
	input_limits.clear()
	output_limits.clear()

	if not active_recipe.is_empty():
		for resource_name in _cached_recipe_inputs:
			inputs[resource_name] = 0.0
			input_limits[resource_name] = maxf(_cached_recipe_inputs[resource_name] * 10.0, 20.0)

		for resource_name in _cached_recipe_outputs:
			outputs[resource_name] = 0.0
			output_limits[resource_name] = maxf(_cached_recipe_outputs[resource_name] * 10.0, 20.0)
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

## Simulates a single tick of duration `delta` (usually 1.0 second).
## Note: This will be moved to ProductionSystem, but kept here temporarily for compatibility.
func tick(delta: float = 1.0, speed_multiplier: float = 1.0) -> void:
	if is_splitter:
		return

	if active_recipe.is_empty():
		return

	var effective_delta = delta * speed_multiplier

	if not is_producing:
		# Check if we have enough inputs
		var can_start = true
		for resource_name in _cached_recipe_inputs:
			if inputs.get(resource_name, 0.0) < _cached_recipe_inputs[resource_name]:
				can_start = false
				break

		# Check if output buffers have enough space for the batch
		if can_start:
			for resource_name in _cached_recipe_outputs:
				if outputs.get(resource_name, 0.0) + _cached_recipe_outputs[resource_name] > output_limits.get(resource_name, 20.0):
					can_start = false
					break

		if can_start:
			# Consume inputs immediately at start of cycle
			for resource_name in _cached_recipe_inputs:
				inputs[resource_name] -= _cached_recipe_inputs[resource_name]
			is_producing = true
			production_progress = 0.0
			ui_version += 1

	if is_producing:
		production_progress += effective_delta
		if production_progress >= _cached_duration - 0.0001: # Avoid floating point issues
			# Complete production: add products to outputs
			for resource_name in _cached_recipe_outputs:
				var limit = output_limits.get(resource_name, 20.0)
				outputs[resource_name] = minf(outputs.get(resource_name, 0.0) + _cached_recipe_outputs[resource_name], limit)
			is_producing = false
			production_progress = 0.0
			ui_version += 1


## Serializes building data state to dictionary.
func to_dict() -> Dictionary:
	return {
		"id": id,
		"type": type,
		"grid_position": [grid_position.x, grid_position.y],
		"size_in_cells": [size_in_cells.x, size_in_cells.y],
		"inputs": inputs.duplicate(),
		"input_limits": input_limits.duplicate(),
		"outputs": outputs.duplicate(),
		"output_limits": output_limits.duplicate(),
		"active_recipe": active_recipe.duplicate(),
		"production_progress": production_progress,
		"is_producing": is_producing
	}

## Deserializes building data state from dictionary.
static func from_dict(data_dictionary: Dictionary) -> BuildingData:
	var parsed_position = Vector2i(int(data_dictionary["grid_position"][0]), int(data_dictionary["grid_position"][1]))
	var parsed_recipe = data_dictionary.get("active_recipe", {}).duplicate()
	var parsed_size = get_default_size(data_dictionary.get("type", ""))

	var building_instance = BuildingData.new(int(data_dictionary["id"]), data_dictionary["type"], parsed_position, parsed_recipe, parsed_size)

	var raw_inputs: Dictionary = data_dictionary.get("inputs", {})
	for resource_name in raw_inputs:
		building_instance.inputs[resource_name] = roundf(float(raw_inputs[resource_name]))

	building_instance.input_limits = data_dictionary.get("input_limits", {}).duplicate()

	var raw_outputs: Dictionary = data_dictionary.get("outputs", {})
	for resource_name in raw_outputs:
		building_instance.outputs[resource_name] = roundf(float(raw_outputs[resource_name]))

	building_instance.output_limits = data_dictionary.get("output_limits", {}).duplicate()
	building_instance.production_progress = data_dictionary.get("production_progress", 0.0)
	building_instance.is_producing = data_dictionary.get("is_producing", false)
	return building_instance
