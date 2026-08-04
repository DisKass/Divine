class_name FlowSystem
extends RefCounted

## Handles routing, connections, and transferring items between buildings.
## Operates on FactoryState.

static func add_connection(state: FactoryState, from_id: int, to_id: int, from_port: int = 0, to_port: int = 0) -> bool:
	if from_id == to_id:
		return false

	if not state.buildings.has(from_id) or not state.buildings.has(to_id):
		return false

	var from_building: BuildingData = state.buildings[from_id]
	var to_building: BuildingData = state.buildings[to_id]
	
	if from_port < 0 or from_port >= from_building.get_port_count(true):
		return false
	if to_port < 0 or to_port >= to_building.get_port_count(false):
		return false
		
	var source_slot = from_building.get_port_slot(true, from_port)
	var target_slot = to_building.get_port_slot(false, to_port)
	
	if source_slot != null and target_slot != null:
		var source_res = source_slot.current_item
		if source_res == "" and source_slot.accepted_tags.size() > 0:
			source_res = source_slot.accepted_tags[0]
			
		if source_res != "":
			if not target_slot.can_accept(source_res):
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

	for portal in state.factory.buildings_list:
		if portal.type == "portal":
			portal.input_slots.clear()
			for resource_name in requirements.keys():
				var req_amount = float(requirements[resource_name])
				var cur_amount = float(progress.get(resource_name, 0.0))
				var limit = maxf(req_amount - cur_amount, 0.0)
				var slot = ItemSlot.new([resource_name], limit)
				portal.input_slots.append(slot)
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
		var out_slots = from_building_first.shared_slots if from_building_first.config.buffer_mode == "shared" else from_building_first.output_slots

		var has_any_output = false
		for slot in out_slots:
			if slot.amount >= 1.0:
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
			var cached_resources: Array[String] = cache_entry[5] # output tags this connection can handle

			if cached_resources.is_empty():
				continue

			var transfer_made = false
			
			for out_slot in out_slots:
				if out_slot.amount < 1.0:
					continue
					
				var res_name = out_slot.current_item
				if res_name == "": continue
				
				# Does this connection support this resource?
				var supported = false
				for cr in cached_resources:
					if res_name == cr or ItemTagSystem.has_tag(res_name, cr):
						supported = true
						break
				
				if not supported:
					continue
					
				var available_units = floori(out_slot.amount)
				if available_units <= 0: continue
				
				if to_building.config.process_logic == "passthrough":
					state.factory.temp_visited_splitters.clear()
					if _try_transfer_through_splitter(state, from_building, out_slot, from_port, to_building, to_port, connection_data):
						transfer_made = true
						break
				else:
					var target_slot = to_building.get_port_slot(false, to_port)
					
					if target_slot and target_slot.can_accept(res_name):
						var space = floori(target_slot.get_available_space())
						if space > 0:
							var amount_to_transfer = 1.0 # 1 item per tick per link
							
							var pulled = out_slot.pull(amount_to_transfer)
							target_slot.push(res_name, pulled.amount, pulled.payload)
							
							from_building.ui_version += 1
							to_building.ui_version += 1
							
							connection_data["is_active"] = true
							transfer_made = true
							state.factory.resource_transferred.emit(from_building.id, from_port, to_building.id, to_port, res_name, 1.0, 1.0)
							break
							
			if transfer_made:
				from_building.last_outgoing_connection_index = (connection_index + 1) % num_connections
				break

static func _try_transfer_through_splitter(state: GameState, original_from: BuildingData, out_slot: ItemSlot, from_port: int, splitter_building: BuildingData, to_port: int, connection_data: Dictionary) -> bool:
	if state.factory.temp_visited_splitters.has(splitter_building.id):
		return false
	state.factory.temp_visited_splitters[splitter_building.id] = true
	
	var res_name = out_slot.current_item

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

		if target_building.config.process_logic == "passthrough":
			if _try_transfer_through_splitter(state, original_from, out_slot, from_port, target_building, target_to_port, target_connection_data):
				splitter_building.last_outgoing_connection_index = (connection_index + 1) % num_connections
				connection_data["is_active"] = true
				return true
		else:
			var target_slot = target_building.get_port_slot(false, target_to_port)
			
			if target_slot and target_slot.can_accept(res_name):
				var space = floori(target_slot.get_available_space())
				if space > 0:
					var amount_to_transfer = 1.0
					
					var pulled = out_slot.pull(amount_to_transfer)
					target_slot.push(res_name, pulled.amount, pulled.payload)
					
					original_from.ui_version += 1
					target_building.ui_version += 1
					
					splitter_building.last_outgoing_connection_index = (connection_index + 1) % num_connections
					connection_data["is_active"] = true
					target_connection_data["is_active"] = true
					state.factory.resource_transferred.emit(splitter_building.id, splitter_from_port, target_building.id, target_to_port, res_name, 1.0, 1.0)
					return true
					
	return false
