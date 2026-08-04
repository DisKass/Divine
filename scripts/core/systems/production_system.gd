class_name ProductionSystem
extends RefCounted

## Handles recipe processing inside buildings.
## Operates on GameState.

static func tick(state: GameState, delta: float) -> void:
	for building_instance in state.factory.buildings_list:
		if building_instance.config.process_logic == "passthrough":
			continue
			
		if building_instance.type == "portal":
			var cleared_any = false
			for slot in building_instance.input_slots:
				if not slot.is_empty():
					var amount = slot.amount
					MilestoneSystem.submit_portal_resource(state, slot.current_item, amount)
					slot.clear()
					cleared_any = true
			if cleared_any:
				building_instance.ui_version += 1
			continue
			
		if building_instance.config.process_logic == "void":
			var cleared_any = false
			for slot in building_instance.input_slots:
				if not slot.is_empty():
					slot.clear()
					cleared_any = true
			if cleared_any:
				building_instance.ui_version += 1
			continue
			
		if building_instance.type == "vault_gateway" and building_instance.vault_gateway_mode == "store":
			if building_instance.shared_slots.size() > 0:
				var slot = building_instance.shared_slots[0]
				if not slot.is_empty():
					if ArtifactSystem.store_artifact_in_vault(state, slot.payload):
						slot.clear()
						building_instance.ui_version += 1
			continue
			
		if building_instance.config.process_logic == "forge_artifact":
			# TODO: implement forge artifact logic later
			continue

		if building_instance.active_recipe.is_empty():
			continue

		var mult_name = "miner_speed" if building_instance.type.begins_with("miner") else "factory_speed"
		var speed_multiplier = ModifierSystem.get_multiplier(state, mult_name, building_instance)
		var effective_delta = delta * speed_multiplier

		var _cached_recipe_inputs = building_instance.active_recipe.get("inputs", {})
		var _cached_recipe_outputs = building_instance.active_recipe.get("outputs", {})

		if not building_instance.is_producing:
			# Check if we have enough inputs
			var can_start = true
			for resource_name in _cached_recipe_inputs:
				if str(resource_name).begins_with("_"): continue
				
				var found_amount = 0.0
				for slot in building_instance.input_slots:
					if slot.current_item == resource_name:
						found_amount += slot.amount
				
				if found_amount < float(_cached_recipe_inputs[resource_name]):
					can_start = false
					break

			# Check if output buffers have enough space for the batch
			if can_start and building_instance.config.global_output_link == "":
				for resource_name in _cached_recipe_outputs:
					if str(resource_name).begins_with("_"): continue
					
					var matching_slot: ItemSlot = null
					for slot in building_instance.output_slots:
						if slot.current_item == resource_name or slot.is_empty():
							matching_slot = slot
							break
					
					if matching_slot:
						if matching_slot.get_available_space() < float(_cached_recipe_outputs[resource_name]):
							can_start = false
							break
					else:
						can_start = false
						break

			if can_start:
				# Consume inputs immediately at start of cycle
				for resource_name in _cached_recipe_inputs:
					if str(resource_name).begins_with("_"): continue
					var amount_to_consume = float(_cached_recipe_inputs[resource_name])
					for slot in building_instance.input_slots:
						if slot.current_item == resource_name:
							var pulled = slot.pull(amount_to_consume)
							amount_to_consume -= pulled.amount
							if amount_to_consume <= 0:
								break
								
				building_instance.is_producing = true
				building_instance.production_progress = 0.0
				building_instance.ui_version += 1

		if building_instance.is_producing:
			building_instance.production_progress += effective_delta
			if building_instance.production_progress >= building_instance._cached_duration - 0.0001:
				# Complete production: add products to outputs
				for resource_name in _cached_recipe_outputs:
					if str(resource_name).begins_with("_"): continue
					
					var amount_to_produce = float(_cached_recipe_outputs[resource_name])
					
					if building_instance.config.global_output_link == "credits":
						ResourceSystem.add_resource(state, "credits", amount_to_produce)
					elif building_instance.config.global_output_link == "portal":
						MilestoneSystem.submit_portal_resource(state, resource_name, amount_to_produce)
					else:
						var payload_to_push = {}
						if building_instance.type == "shell_forge":
							payload_to_push = ArtifactSystem.generate_artifact(resource_name)
							
						for slot in building_instance.output_slots:
							if slot.current_item == resource_name or slot.is_empty():
								var pushed = slot.push(resource_name, amount_to_produce, payload_to_push)
								amount_to_produce -= pushed
								if amount_to_produce <= 0:
									break
									
				building_instance.is_producing = false
				building_instance.production_progress = 0.0
				building_instance.ui_version += 1
