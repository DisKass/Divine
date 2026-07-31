class_name FlowSystem
extends RefCounted

## Handles routing, connections, and transferring items between buildings.
## Operates on FactoryState.

static func add_connection(state: FactoryState, from_id: int, to_id: int, from_port: int = 0, to_port: int = 0) -> bool:
	if from_id == to_id:
		return false # No self-connections

	if not state.buildings.has(from_id) or not state.buildings.has(to_id):
		return false

	var from_building = state.buildings[from_id]
	var to_building = state.buildings[to_id]

	# Verify that the output of from_building matches at least one input of to_building
	var has_matching_resource = false
	if to_building.is_portal:
		for output_resource in from_building.outputs:
			if to_building.input_limits.has(output_resource):
				has_matching_resource = true
				break
	elif to_building.is_vault_gateway:
		for output_resource in from_building.outputs:
			if ArtifactSystem.artifact_configs.has(output_resource):
				to_building.inputs[output_resource] = to_building.inputs.get(output_resource, 0.0)
				to_building.input_limits[output_resource] = 1.0
				has_matching_resource = true
				break
	elif to_building.is_splitter or from_building.is_splitter:
		has_matching_resource = true
		for output_resource in from_building.outputs:
			to_building.inputs[output_resource] = to_building.inputs.get(output_resource, 0.0)
			if to_building.is_splitter:
				to_building.input_limits[output_resource] = 1.0
			else:
				to_building.input_limits[output_resource] = maxf(to_building.input_limits.get(output_resource, 20.0), 20.0)
	else:
		for output_resource in from_building.outputs:
			if to_building.inputs.has(output_resource) or to_building.active_recipe.get("inputs", {}).has(output_resource):
				to_building.inputs[output_resource] = to_building.inputs.get(output_resource, 0.0)
				to_building.input_limits[output_resource] = maxf(to_building.input_limits.get(output_resource, 20.0), 20.0)
				has_matching_resource = true
				break

	if not has_matching_resource:
		return false

	# Remove any existing connection originating from (from_id, from_port)
	var index = 0
	while index < state.connections.size():
		if state.connections[index]["from_id"] == from_id and int(state.connections[index].get("from_port", 0)) == from_port:
			state.connections.remove_at(index)
		else:
			index += 1

	state.connections.append({
		"from_id": from_id,
		"from_port": from_port,
		"to_id": to_id,
		"to_port": to_port
	})

	if not state.batch_mode:
		state.rebuild_caches()
	return true

static func remove_connection(state: FactoryState, from_id: int, to_id: int, from_port: int = 0) -> void:
	var index_to_remove = -1
	for i in range(state.connections.size()):
		var connection_data = state.connections[i]
		if connection_data["from_id"] == from_id and connection_data["to_id"] == to_id and int(connection_data.get("from_port", 0)) == from_port:
			index_to_remove = i
			break

	if index_to_remove != -1:
		state.connections.remove_at(index_to_remove)
		if not state.batch_mode:
			state.rebuild_caches()

static func sync_portal_inputs(state: GameState) -> void:
	var milestone_info = MilestoneSystem.get_current_milestone(state)
	var requirements = milestone_info.get("requirements", {})
	var progress = milestone_info.get("progress", {})

	for portal in state.factory.portals:
		for resource_name in portal.inputs.keys():
			portal.inputs.erase(resource_name)
			portal.input_limits.erase(resource_name)

		for resource_name in requirements.keys():
			portal.inputs[resource_name] = float(progress.get(resource_name, 0.0))
			portal.input_limits[resource_name] = float(requirements[resource_name])
		portal.ui_version += 1

static func tick(state: GameState, sell_mult: float = 1.0) -> void:
	# Reset transfer activity flags on connections
	for connection_data in state.factory.connections:
		connection_data["is_active"] = false
		connection_data["flow_rate"] = 0.0

	# Distribute resources along connections (Instant transfer per tick)
	for outgoing_group in state.factory.building_outgoing_connections:
		var num_connections = outgoing_group.size()
		if num_connections == 0:
			continue

		var from_building_first: BuildingData = outgoing_group[0][0]

		var has_any_output = false
		for resource_name in from_building_first.outputs:
			if from_building_first.outputs[resource_name] >= 1.0:
				has_any_output = true
				break

		if not has_any_output:
			continue

		var start_connection_index = from_building_first.last_outgoing_connection_index % num_connections

		for connection_step in range(num_connections):
			var connection_index = (start_connection_index + connection_step) % num_connections
			var cache_entry = outgoing_group[connection_index]

			var from_building: BuildingData = cache_entry[0]
			var to_building: BuildingData = cache_entry[1]
			var connection_data: Dictionary = cache_entry[2]
			var from_port: int = cache_entry[3]
			var to_port: int = cache_entry[4]
			var resources: Array[String] = cache_entry[5]

			if resources.is_empty():
				continue

			var num_resources = resources.size()
			var start_resource_index = int(connection_data.get("last_res_index", 0)) % num_resources

			for i in range(num_resources):
				var resource_index = (start_resource_index + i) % num_resources
				var resource_name = resources[resource_index]

				var available_units = floori(from_building.outputs.get(resource_name, 0.0))
				if available_units <= 0:
					continue

				if to_building.is_splitter:
					state.factory.temp_visited_splitters.clear()
					if _try_transfer_through_splitter(state, from_building, from_port, to_building, to_port, resource_name, connection_data):
						from_building.last_outgoing_connection_index = (connection_index + 1) % num_connections
						connection_data["last_res_index"] = (resource_index + 1) % num_resources
						break
				elif to_building.is_vault_gateway:
					if _try_transfer_to_vault(state, from_building, from_port, to_building, to_port, resource_name, connection_data):
						from_building.last_outgoing_connection_index = (connection_index + 1) % num_connections
						connection_data["last_res_index"] = (resource_index + 1) % num_resources
						break
				else:
					var target_current = to_building.inputs.get(resource_name, 0.0)
					var target_limit = to_building.input_limits.get(resource_name, 0.0 if to_building.is_portal else 20.0)
					var space_units = floori(target_limit - target_current)

					if space_units <= 0:
						continue

					var units_to_move = min(available_units, space_units)
					if units_to_move > 0:
						from_building.outputs[resource_name] -= float(units_to_move)
						to_building.inputs[resource_name] = to_building.inputs.get(resource_name, 0.0) + float(units_to_move)
						from_building.ui_version += 1
						to_building.ui_version += 1
						connection_data["is_active"] = true
						connection_data["last_res_index"] = (resource_index + 1) % num_resources
						from_building.last_outgoing_connection_index = (connection_index + 1) % num_connections
						state.factory.resource_transferred.emit(from_building.id, from_port, to_building.id, to_port, resource_name, float(units_to_move), 1.0)
						break

	# Harvest global credits from outputs, process Portal deliveries & collect crafted Artifacts
	for building_instance in state.factory.credits_producers:
		var amount = building_instance.outputs.get("credits", 0.0)
		if amount > 0.0:
			ResourceSystem.add_resource(state, "credits", amount * sell_mult)
			building_instance.outputs["credits"] = 0.0

	for portal in state.factory.portals:
		var current_keys = portal.inputs.keys()
		for resource_name in current_keys:
			if not resource_name.begins_with("_") and portal.inputs.has(resource_name):
				var amount = float(portal.inputs.get(resource_name, 0.0))
				if amount > 0.0:
					MilestoneSystem.submit_portal_resource(state, resource_name, amount)



static func _try_transfer_to_vault(state: GameState, from_building: BuildingData, from_port: int, vault: BuildingData, to_port: int, resource_name: String, connection_data: Dictionary) -> bool:
	ArtifactSystem.ensure_configs_loaded()
	if not ArtifactSystem.artifact_configs.has(resource_name):
		return false
	
	if ArtifactSystem.add_artifact_base_to_inventory(state, resource_name):
		from_building.outputs[resource_name] -= 1.0
		from_building.ui_version += 1
		connection_data["is_active"] = true
		state.factory.resource_transferred.emit(from_building.id, from_port, vault.id, to_port, resource_name, 1.0, 1.0)
		return true
	return false

static func _try_transfer_through_splitter(state: GameState, from_building: BuildingData, from_port: int, splitter_building: BuildingData, to_port: int, resource_name: String, connection_data: Dictionary) -> bool:
	if state.factory.temp_visited_splitters.has(splitter_building.id):
		return false
	state.factory.temp_visited_splitters[splitter_building.id] = true

	var outgoing: Array = state.factory.building_outgoing_connections_map.get(splitter_building.id, [])
	var num_connections = outgoing.size()
	if num_connections == 0:
		return false

	var start_connection_index = splitter_building.last_outgoing_connection_index % num_connections

	for connection_step in range(num_connections):
		var connection_index = (start_connection_index + connection_step) % num_connections
		var cache_entry = outgoing[connection_index]

		var target_building: BuildingData = cache_entry[1]
		var target_connection_data: Dictionary = cache_entry[2]
		var splitter_from_port: int = cache_entry[3]
		var target_to_port: int = cache_entry[4]

		if target_building.is_splitter:
			if _try_transfer_through_splitter(state, from_building, from_port, target_building, target_to_port, resource_name, connection_data):
				splitter_building.last_outgoing_connection_index = (connection_index + 1) % num_connections
				state.factory.resource_transferred.emit(splitter_building.id, splitter_from_port, target_building.id, target_to_port, resource_name, 1.0, 1.0)
				target_connection_data["is_active"] = true
				return true
		elif target_building.is_vault_gateway:
			if _try_transfer_to_vault(state, from_building, from_port, target_building, target_to_port, resource_name, connection_data):
				splitter_building.last_outgoing_connection_index = (connection_index + 1) % num_connections
				state.factory.resource_transferred.emit(splitter_building.id, splitter_from_port, target_building.id, target_to_port, resource_name, 1.0, 1.0)
				target_connection_data["is_active"] = true
				return true
		else:
			var target_current = target_building.inputs.get(resource_name, 0.0)
			var target_limit = target_building.input_limits.get(resource_name, 20.0)
			var space_units = floori(target_limit - target_current)
			if space_units > 0:
				from_building.outputs[resource_name] -= 1.0
				target_building.inputs[resource_name] = target_current + 1.0
				from_building.ui_version += 1
				target_building.ui_version += 1

				splitter_building.last_outgoing_connection_index = (connection_index + 1) % num_connections
				connection_data["is_active"] = true
				target_connection_data["is_active"] = true

				state.factory.resource_transferred.emit(from_building.id, from_port, splitter_building.id, to_port, resource_name, 1.0, 1.0)
				state.factory.resource_transferred.emit(splitter_building.id, splitter_from_port, target_building.id, target_to_port, resource_name, 1.0, 1.0)
				return true

	return false
