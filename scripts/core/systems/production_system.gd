class_name ProductionSystem
extends RefCounted

## Handles recipe processing, artifact infusion/purification, and PoE affixes inside buildings.
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
			continue

		# --- SPECIAL TRANSIT LOGIC FOR SHELL INFUSER & PURIFIER ---
		if building_instance.type == "shell_infuser":
			var artifact_slot: ItemSlot = null
			for slot in building_instance.input_slots:
				if slot.matches_resource("<artifact>"):
					artifact_slot = slot
					break
			if artifact_slot != null and not artifact_slot.payload.is_empty():
				var item = ItemData.from_dict(artifact_slot.payload)
				if not item.is_white():
					# Colored artifact (>0 affixes) passes directly to output without essence cost or delay
					var out_slot = building_instance.output_slots[0] if building_instance.output_slots.size() > 0 else null
					if out_slot != null and out_slot.get_available_space() >= 1.0:
						var pulled_res = artifact_slot.current_item
						var pulled_payload = artifact_slot.payload.duplicate(true)
						artifact_slot.clear()
						out_slot.push(pulled_res, 1.0, pulled_payload)
						building_instance.ui_version += 1
						continue

		if building_instance.type == "purifier":
			var artifact_slot: ItemSlot = null
			for slot in building_instance.input_slots:
				if slot.matches_resource("<artifact>"):
					artifact_slot = slot
					break
			if artifact_slot != null and not artifact_slot.payload.is_empty():
				var item = ItemData.from_dict(artifact_slot.payload)
				if item.is_white():
					# White artifact (0 affixes) passes directly to output without delay
					var out_slot = building_instance.output_slots[0] if building_instance.output_slots.size() > 0 else null
					if out_slot != null and out_slot.get_available_space() >= 1.0:
						var pulled_res = artifact_slot.current_item
						var pulled_payload = artifact_slot.payload.duplicate(true)
						artifact_slot.clear()
						out_slot.push(pulled_res, 1.0, pulled_payload)
						building_instance.ui_version += 1
						continue

		if building_instance.active_recipe.is_empty():
			continue

		# Calculate Speed Multipliers
		var mult_name = "miner_speed" if building_instance.type.begins_with("miner") else "factory_speed"
		var base_speed_multiplier = ModifierSystem.get_multiplier(state, mult_name, building_instance)
		var total_speed_multiplier = base_speed_multiplier * (1.0 + building_instance.active_accel_bonus)
		var effective_delta = delta * total_speed_multiplier

		var _cached_recipe_inputs = building_instance.active_recipe.get("inputs", {})
		var _cached_recipe_outputs = building_instance.active_recipe.get("outputs", {})

		if not building_instance.is_producing:
			# Track idle / interruption time
			building_instance.idle_time += delta
			if building_instance.idle_time >= 2.0:
				building_instance.was_interrupted = true

			# Check if we have enough inputs in slots
			var can_start = true
			for resource_name in _cached_recipe_inputs:
				if str(resource_name).begins_with("_"): continue
				
				var found_amount = 0.0
				for slot in building_instance.input_slots:
					if slot.matches_resource(resource_name):
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
						if slot.current_item == resource_name or slot.is_empty() or resource_name == "<artifact>":
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
				# Apply Acceleration Bonus (Interrupted vs Continuous)
				if building_instance.was_interrupted:
					building_instance.active_accel_bonus = ModifierSystem.get_bonus(state, "acceleration_inter", building_instance) / 100.0
				else:
					building_instance.active_accel_bonus = ModifierSystem.get_bonus(state, "acceleration_cont", building_instance) / 100.0
				
				building_instance.idle_time = 0.0
				building_instance.was_interrupted = false

				# Roll Save Input Chance
				var save_chance = ModifierSystem.get_bonus(state, "save_input_chance", building_instance) / 100.0
				var save_input = (randf() < save_chance)

				# Consume inputs immediately at start of cycle (unless saved)
				for resource_name in _cached_recipe_inputs:
					if str(resource_name).begins_with("_"): continue
					var amount_to_consume = float(_cached_recipe_inputs[resource_name])
					for slot in building_instance.input_slots:
						if slot.matches_resource(resource_name):
							if resource_name == "<artifact>":
								building_instance.held_artifact = slot.payload.duplicate(true)
								slot.clear()
								amount_to_consume = 0.0
								break
							else:
								if not save_input:
									var pulled = slot.pull(amount_to_consume)
									amount_to_consume -= pulled.amount
									if amount_to_consume <= 0:
										break
								else:
									amount_to_consume = 0.0
									break

				building_instance.is_producing = true
				building_instance.production_progress = 0.0

				# Roll Crit Craft Chance (Instant completion)
				var crit_chance = ModifierSystem.get_bonus(state, "crit_craft_chance", building_instance) / 100.0
				if randf() < crit_chance:
					building_instance.production_progress = building_instance._cached_duration

				building_instance.ui_version += 1

		if building_instance.is_producing:
			building_instance.production_progress += effective_delta
			if building_instance.production_progress >= building_instance._cached_duration - 0.0001:
				# Complete production: calculate outputs with affixes
				for resource_name in _cached_recipe_outputs:
					if str(resource_name).begins_with("_"): continue
					
					var amount_to_produce = float(_cached_recipe_outputs[resource_name])
					var is_artifact_output = (resource_name == "<artifact>" or ItemTagSystem.has_tag(resource_name, "<artifact>") or building_instance.type in ["shell_forge", "shell_infuser", "purifier"])

					if not is_artifact_output:
						# Flat Production Modifier
						var prod_flat = ModifierSystem.get_bonus(state, "production_flat", building_instance)
						amount_to_produce += prod_flat

						# Double Craft Chance Modifier
						var dbl_chance = minf(1.0, ModifierSystem.get_bonus(state, "double_craft_chance", building_instance) / 100.0)
						if randf() < dbl_chance:
							amount_to_produce *= 2.0

						# Extra Flat Chance Modifier
						var extra_chance = ModifierSystem.get_bonus(state, "extra_flat_chance", building_instance) / 100.0
						if extra_chance > 0.0:
							var extra_amt = floorf(extra_chance) + (1.0 if randf() < (extra_chance - floorf(extra_chance)) else 0.0)
							amount_to_produce += extra_amt
					else:
						amount_to_produce = 1.0
					
					if building_instance.config.global_output_link == "credits":
						var sell_mult = ModifierSystem.get_multiplier(state, "sell_multiplier", building_instance)
						ResourceSystem.add_resource(state, "credits", amount_to_produce * sell_mult)
					elif building_instance.config.global_output_link == "portal":
						MilestoneSystem.submit_portal_resource(state, resource_name, amount_to_produce)
					else:
						var payload_to_push = {}
						var final_item_name = resource_name

						if building_instance.type == "shell_forge":
							payload_to_push = ArtifactSystem.generate_artifact(resource_name)
						elif building_instance.type == "shell_infuser":
							var in_payload = building_instance.held_artifact.duplicate(true)
							building_instance.held_artifact.clear()
							payload_to_push = ArtifactSystem.infuse_artifact(in_payload)
							final_item_name = payload_to_push.get("base_id", "runesteel_amulet")
						elif building_instance.type == "purifier":
							var in_payload = building_instance.held_artifact.duplicate(true)
							building_instance.held_artifact.clear()
							payload_to_push = ArtifactSystem.purify_artifact(in_payload)
							final_item_name = payload_to_push.get("base_id", "runesteel_amulet")

						for slot in building_instance.output_slots:
							if slot.current_item == final_item_name or slot.is_empty() or final_item_name == "<artifact>":
								var target_res_name = slot.current_item if not slot.is_empty() else final_item_name
								if target_res_name == "<artifact>" and not payload_to_push.is_empty():
									target_res_name = payload_to_push.get("base_id", "runesteel_amulet")
								var pushed = slot.push(target_res_name, amount_to_produce, payload_to_push)
								amount_to_produce -= pushed
								if amount_to_produce <= 0:
									break
									
				building_instance.is_producing = false
				building_instance.production_progress = 0.0
				building_instance.ui_version += 1
