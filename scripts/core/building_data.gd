class_name BuildingData
extends RefCounted

## Represents a building instance in the factory simulation.
## Decoupled from Godot's visual representation for high-performance tick execution.

var id: int
var type: String
var grid_position: Vector2i

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

func _init(p_id: int, p_type: String, p_pos: Vector2i, p_recipe: Dictionary = {}) -> void:
	id = p_id
	type = p_type
	grid_position = p_pos
	active_recipe = p_recipe
	
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

## Simulates a single tick of duration `delta` (usually 1.0 second).
func tick(delta: float = 1.0) -> void:
	if active_recipe.is_empty():
		return
		
	var recipe_inputs = active_recipe.get("inputs", {})
	var recipe_outputs = active_recipe.get("outputs", {})
	var duration = float(active_recipe.get("duration", 1.0))
	
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
		production_progress += delta
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
	var pos = Vector2i(dict["grid_position"][0], dict["grid_position"][1])
	var recipe = dict.get("active_recipe", {}).duplicate()
	var b = BuildingData.new(dict["id"], dict["type"], pos, recipe)
	
	b.inputs = dict.get("inputs", {}).duplicate()
	b.input_limits = dict.get("input_limits", {}).duplicate()
	b.outputs = dict.get("outputs", {}).duplicate()
	b.output_limits = dict.get("output_limits", {}).duplicate()
	b.production_progress = dict.get("production_progress", 0.0)
	b.is_producing = dict.get("is_producing", false)
	return b
