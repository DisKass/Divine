class_name BuildingData
extends RefCounted

## Represents a building instance in the factory simulation.
## Decoupled from Godot's visual representation for high-performance tick execution.

const DEFAULT_SIZES: Dictionary = {
	"miner": Vector2i(3, 2),
	"smelter": Vector2i(4, 2),
	"converter": Vector2i(4, 2),
	"assembler": Vector2i(4, 3),
	"extractor": Vector2i(4, 2),
	"infuser": Vector2i(4, 3),
	"portal": Vector2i(4, 3),
	"seller": Vector2i(4, 2),
	"splitter_2": Vector2i(1, 2),
	"splitter_3": Vector2i(1, 2),
	# Backwards compatibility
	"miner_iron": Vector2i(3, 2),
	"miner_coal": Vector2i(3, 2),
	"miner_crystal": Vector2i(3, 2),
	"crusher": Vector2i(4, 2),
	"constructor": Vector2i(4, 2),
	"alchemy_lab": Vector2i(4, 3),
	"artifact_altar": Vector2i(4, 3)
}

static func get_default_size(p_type: String) -> Vector2i:
	return DEFAULT_SIZES.get(p_type, Vector2i(4, 2))

static func get_output_ports_count(p_type: String, p_recipe: Dictionary = {}) -> int:
	match p_type:
		"splitter_2": return 2
		"splitter_3": return 3
		"portal", "seller": return 0
		_:
			var out_dict = p_recipe.get("outputs", {})
			var real_count = 0
			for k in out_dict:
				if not str(k).begins_with("_"):
					real_count += 1
			return max(1, real_count)

static func get_input_ports_count(p_type: String, p_recipe: Dictionary = {}) -> int:
	match p_type:
		"miner": return 0
		"assembler", "infuser":
			var in_dict = p_recipe.get("inputs", {})
			var real_count = 0
			for k in in_dict:
				if not str(k).begins_with("_"):
					real_count += 1
			return max(2, real_count)
		_:
			var in_dict = p_recipe.get("inputs", {})
			var real_count = 0
			for k in in_dict:
				if not str(k).begins_with("_"):
					real_count += 1
			return max(1, real_count)

var id: int
var type: String
var grid_position: Vector2i
var size_in_cells: Vector2i = Vector2i(4, 2)
var last_outgoing_conn_index: int = 0

# Buffers: resource_name (String) -> amount (float)
var inputs: Dictionary = {}
var input_limits: Dictionary = {}
var outputs: Dictionary = {}
var output_limits: Dictionary = {}

# Active production recipe
# Format:
# {
#   "inputs": { "resource_name": amount },
#   "outputs": { "resource_name": amount },
#   "duration": float (ticks required)
# }
var active_recipe: Dictionary = {}
var production_progress: float = 0.0
var is_producing: bool = false

func _init(p_id: int, p_type: String, p_pos: Vector2i, p_recipe: Dictionary = {}, p_size: Vector2i = Vector2i.ZERO) -> void:
	id = p_id
	type = p_type
	grid_position = p_pos
	active_recipe = p_recipe
	size_in_cells = p_size if p_size != Vector2i.ZERO else get_default_size(p_type)
	
	# Initialize buffers from recipe if present
	if not active_recipe.is_empty():
		var r_inputs = active_recipe.get("inputs", {})
		for res in r_inputs:
			inputs[res] = 0.0
			# Input buffer limit is 10x recipe requirements or a minimum default of 20
			input_limits[res] = maxf(r_inputs[res] * 10.0, 20.0)
			
		var r_outputs = active_recipe.get("outputs", {})
		for res in r_outputs:
			outputs[res] = 0.0
			# Output buffer limit is 10x recipe requirements or a minimum default of 20
			output_limits[res] = maxf(r_outputs[res] * 10.0, 20.0)

## Returns all grid cell coordinates occupied by this building.
func get_occupied_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(size_in_cells.x):
		for y in range(size_in_cells.y):
			cells.append(grid_position + Vector2i(x, y))
	return cells

## Changes the active recipe of the building, resetting production progress and buffers.
func set_recipe(p_recipe: Dictionary) -> void:
	active_recipe = p_recipe.duplicate(true)
	production_progress = 0.0
	production_progress = 0.0
	is_producing = false
	
	inputs.clear()
	outputs.clear()
	input_limits.clear()
	output_limits.clear()
	
	if not active_recipe.is_empty():
		var r_inputs = active_recipe.get("inputs", {})
		for res in r_inputs:
			inputs[res] = 0.0
			input_limits[res] = maxf(r_inputs[res] * 10.0, 20.0)
			
		var r_outputs = active_recipe.get("outputs", {})
		for res in r_outputs:
			outputs[res] = 0.0
			output_limits[res] = maxf(r_outputs[res] * 10.0, 20.0)

## Simulates a single tick of duration `delta` (usually 1.0 second).
func tick(delta: float = 1.0, speed_multiplier: float = 1.0) -> void:
	if type.begins_with("splitter"):
		for res in inputs.keys():
			var amt = inputs[res]
			if amt > 0.0:
				var current_out = outputs.get(res, 0.0)
				var space = maxf(0.0, 1.0 - current_out)
				var to_transfer = minf(amt, space)
				if to_transfer > 0.0:
					outputs[res] = current_out + to_transfer
					inputs[res] -= to_transfer
				output_limits[res] = 1.0
				input_limits[res] = 1.0
		return

	if active_recipe.is_empty():
		return
		
	var recipe_inputs = active_recipe.get("inputs", {})
	var recipe_outputs = active_recipe.get("outputs", {})
	var duration = float(active_recipe.get("duration", 1.0))
	var effective_delta = delta * speed_multiplier
	
	if not is_producing:
		# Check if we have enough inputs
		var can_start = true
		for res in recipe_inputs:
			if inputs.get(res, 0.0) < recipe_inputs[res]:
				can_start = false
				break
				
		# Check if output buffers have enough space for the batch
		if can_start:
			for res in recipe_outputs:
				if outputs.get(res, 0.0) + recipe_outputs[res] > output_limits.get(res, 20.0):
					can_start = false
					break
					
		if can_start:
			# Consume inputs immediately at start of cycle
			for res in recipe_inputs:
				inputs[res] -= recipe_inputs[res]
			is_producing = true
			production_progress = 0.0
			
	if is_producing:
		production_progress += effective_delta
		if production_progress >= duration - 0.0001: # Avoid floating point issues
			# Complete production: add products to outputs
			for res in recipe_outputs:
				var limit = output_limits.get(res, 20.0)
				outputs[res] = minf(outputs.get(res, 0.0) + recipe_outputs[res], limit)
			is_producing = false
			production_progress = 0.0


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
static func from_dict(dict: Dictionary) -> BuildingData:
	var pos = Vector2i(int(dict["grid_position"][0]), int(dict["grid_position"][1]))
	var recipe = dict.get("active_recipe", {}).duplicate()
	var size = get_default_size(dict.get("type", ""))
	
	var b = BuildingData.new(int(dict["id"]), dict["type"], pos, recipe, size)
	
	var raw_inputs: Dictionary = dict.get("inputs", {})
	for res in raw_inputs:
		b.inputs[res] = roundf(float(raw_inputs[res]))
		
	b.input_limits = dict.get("input_limits", {}).duplicate()
	
	var raw_outputs: Dictionary = dict.get("outputs", {})
	for res in raw_outputs:
		b.outputs[res] = roundf(float(raw_outputs[res]))
		
	b.output_limits = dict.get("output_limits", {}).duplicate()
	b.production_progress = dict.get("production_progress", 0.0)
	b.is_producing = dict.get("is_producing", false)
	return b

