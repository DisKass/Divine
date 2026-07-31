class_name ProductionSystem
extends RefCounted

## Handles recipe processing inside buildings.
## Operates on FactoryState.

static func tick(state: FactoryState, delta: float, miner_speed_multiplier: float, factory_speed_multiplier: float) -> void:
	for building_instance in state.buildings_list:
		if building_instance.is_splitter:
			continue

		if building_instance.active_recipe.is_empty():
			continue

		var speed_multiplier = miner_speed_multiplier if building_instance.is_miner else factory_speed_multiplier
		var effective_delta = delta * speed_multiplier

		if not building_instance.is_producing:
			# Check if we have enough inputs
			var can_start = true
			for resource_name in building_instance._cached_recipe_inputs:
				if building_instance.inputs.get(resource_name, 0.0) < building_instance._cached_recipe_inputs[resource_name]:
					can_start = false
					break

			# Check if output buffers have enough space for the batch
			if can_start:
				for resource_name in building_instance._cached_recipe_outputs:
					if building_instance.outputs.get(resource_name, 0.0) + building_instance._cached_recipe_outputs[resource_name] > building_instance.output_limits.get(resource_name, 20.0):
						can_start = false
						break

			if can_start:
				# Consume inputs immediately at start of cycle
				for resource_name in building_instance._cached_recipe_inputs:
					building_instance.inputs[resource_name] -= building_instance._cached_recipe_inputs[resource_name]
				building_instance.is_producing = true
				building_instance.production_progress = 0.0
				building_instance.ui_version += 1

		if building_instance.is_producing:
			building_instance.production_progress += effective_delta
			if building_instance.production_progress >= building_instance._cached_duration - 0.0001: # Avoid floating point issues
				# Complete production: add products to outputs
				for resource_name in building_instance._cached_recipe_outputs:
					var limit = building_instance.output_limits.get(resource_name, 20.0)
					building_instance.outputs[resource_name] = minf(building_instance.outputs.get(resource_name, 0.0) + building_instance._cached_recipe_outputs[resource_name], limit)
				building_instance.is_producing = false
				building_instance.production_progress = 0.0
				building_instance.ui_version += 1
