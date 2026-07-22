class_name FactoryNetwork
extends RefCounted

## Manages the factory graph, connections, and resource distribution simulation.
## Highly optimized using pre-cached references for high-speed offline simulation.

signal resource_transferred(from_id: int, from_port: int, to_id: int, to_port: int, resource_name: String, amount: float, transfer_rate: float)

# Map of building ID -> BuildingData
var buildings: Dictionary = {}
# Map of Vector2i -> building ID (for collision checks)
var grid: Dictionary = {}
# List of connections: Array of Dictionary { "from_id": int, "from_port": int, "to_id": int, "to_port": int }
var connections: Array = []

# Next building ID to assign
var next_id: int = 1

# Batch Mode flag
var batch_mode: bool = false

# Performance Caches (rebuilt when network structure changes)
var _buildings_list: Array[BuildingData] = []
var _connection_cache: Array = [] # Array of cached connection structures: [from_building, to_building, conn_dict, from_port, to_port]
var _building_outgoing_conns: Array = []
var _credits_producers: Array[BuildingData] = [] # Cache of buildings that output credits
var _portals: Array[BuildingData] = [] # Cache of portal buildings
var _altars: Array[BuildingData] = [] # Cache of altar buildings

## Checks whether a rectangular area of cells is free of other buildings.
func is_area_free(top_left: Vector2i, size_in_cells: Vector2i, ignore_building_id: int = 0) -> bool:
	for x in range(size_in_cells.x):
		for y in range(size_in_cells.y):
			var cell = top_left + Vector2i(x, y)
			if grid.has(cell):
				var occ_id = grid[cell]
				if occ_id != ignore_building_id:
					return false
	return true

## Adds a new building to the network.
func add_building(type: String, pos: Vector2i, recipe: Dictionary) -> BuildingData:
	var default_size = BuildingData.get_default_size(type)
	if not is_area_free(pos, default_size):
		printerr("Grid position already occupied for area: ", pos, " size: ", default_size)
		return null
		
	var b_id = next_id
	next_id += 1
	
	var building = BuildingData.new(b_id, type, pos, recipe)
	buildings[b_id] = building
	for cell in building.get_occupied_cells():
		grid[cell] = b_id
	
	if not batch_mode:
		rebuild_caches()
	return building

## Moves an existing building to a new position if free.
func move_building(b_id: int, new_pos: Vector2i) -> bool:
	if not buildings.has(b_id):
		return false
		
	var building = buildings[b_id]
	if not is_area_free(new_pos, building.size_in_cells, b_id):
		return false
		
	for cell in building.get_occupied_cells():
		grid.erase(cell)
		
	building.grid_position = new_pos
	for cell in building.get_occupied_cells():
		grid[cell] = b_id
		
	if not batch_mode:
		rebuild_caches()
	return true

## Removes a building and all its connections.
func remove_building(b_id: int) -> void:
	if not buildings.has(b_id):
		return
		
	var building = buildings[b_id]
	for cell in building.get_occupied_cells():
		grid.erase(cell)
	buildings.erase(b_id)
	
	# Remove any connections associated with this building
	var connections_to_keep: Array = []
	for conn in connections:
		if conn["from_id"] != b_id and conn["to_id"] != b_id:
			connections_to_keep.append(conn)
	connections = connections_to_keep
	
	if not batch_mode:
		rebuild_caches()

## Adds a connection from one building's output port to another building's input port.
func add_connection(from_id: int, to_id: int, from_port: int = 0, to_port: int = 0) -> bool:
	if from_id == to_id:
		return false # No self-connections
		
	if not buildings.has(from_id) or not buildings.has(to_id):
		return false
		
	var from_b = buildings[from_id]
	var to_b = buildings[to_id]
	
	# Verify that the output of from_b matches at least one input of to_b
	var has_matching_resource = false
	if to_b.type == "portal" or to_b.type.begins_with("splitter") or from_b.type.begins_with("splitter"):
		has_matching_resource = true
		for out_res in from_b.outputs:
			to_b.inputs[out_res] = to_b.inputs.get(out_res, 0.0)
			to_b.input_limits[out_res] = 9999.0 if to_b.type == "portal" else maxf(to_b.input_limits.get(out_res, 20.0), 20.0)
	else:
		for out_res in from_b.outputs:
			if to_b.inputs.has(out_res) or to_b.active_recipe.get("inputs", {}).has(out_res):
				to_b.inputs[out_res] = to_b.inputs.get(out_res, 0.0)
				to_b.input_limits[out_res] = maxf(to_b.input_limits.get(out_res, 20.0), 20.0)
				has_matching_resource = true
				break
			
	if not has_matching_resource:
		return false
		
	# Remove any existing connection originating from (from_id, from_port)
	var i = 0
	while i < connections.size():
		if connections[i]["from_id"] == from_id and int(connections[i].get("from_port", 0)) == from_port:
			connections.remove_at(i)
		else:
			i += 1
			
	connections.append({
		"from_id": from_id,
		"from_port": from_port,
		"to_id": to_id,
		"to_port": to_port
	})
	
	if not batch_mode:
		rebuild_caches()
	return true

## Removes a connection.
func remove_connection(from_id: int, to_id: int, from_port: int = 0) -> void:
	var index_to_remove = -1
	for i in range(connections.size()):
		var conn = connections[i]
		if conn["from_id"] == from_id and conn["to_id"] == to_id and int(conn.get("from_port", 0)) == from_port:
			index_to_remove = i
			break
			
	if index_to_remove != -1:
		connections.remove_at(index_to_remove)
		if not batch_mode:
			rebuild_caches()

## Rebuilds the performance caches used during simulation ticks.
func rebuild_caches() -> void:
	# 1. Rebuild building list
	_buildings_list.clear()
	_credits_producers.clear()
	_portals.clear()
	_altars.clear()
	for b in buildings.values():
		_buildings_list.append(b)
		if b.outputs.has("credits"):
			_credits_producers.append(b)
		if b.type == "portal":
			_portals.append(b)
		if b.type == "artifact_altar":
			_altars.append(b)
		
	# 2. Rebuild connection cache with direct object references, grouped by source building ID
	_connection_cache.clear()
	var grouped_by_from: Dictionary = {}
	for conn in connections:
		var from_b = buildings.get(conn["from_id"])
		var to_b = buildings.get(conn["to_id"])
		var from_port = int(conn.get("from_port", 0))
		var to_port = int(conn.get("to_port", 0))
		
		if from_b and to_b:
			var cache_entry = [from_b, to_b, conn, from_port, to_port]
			_connection_cache.append(cache_entry)
			if not grouped_by_from.has(from_b.id):
				grouped_by_from[from_b.id] = []
			grouped_by_from[from_b.id].append(cache_entry)
			
	_building_outgoing_conns = grouped_by_from.values()

## Synchronizes inputs and limits for all Portal buildings to match active milestone requirements.
func sync_portal_inputs(milestones_mgr: MilestonesManager) -> void:
	if milestones_mgr == null:
		return
	var m_info = milestones_mgr.get_current_milestone()
	var reqs: Dictionary = m_info.get("requirements", {})
	var prog: Dictionary = m_info.get("progress", {})
	for p in _portals:
		var keys_to_erase = []
		for k in p.inputs.keys():
			if not reqs.has(k) and not k.begins_with("_"):
				keys_to_erase.append(k)
		for k in keys_to_erase:
			p.inputs.erase(k)
			p.input_limits.erase(k)
			
		for res in reqs.keys():
			p.inputs[res] = float(prog.get(res, 0.0))
			p.input_limits[res] = float(reqs[res])

## Performs a single step of the simulation network (delta in seconds, usually 1.0).
func tick(delta: float = 1.0, resource_mgr: ResourceManager = null, modifier_mgr: ModifierManager = null, milestones_mgr: MilestonesManager = null, artifacts_mgr: ArtifactsManager = null) -> void:
	var miner_speed_mult = 1.0
	var factory_speed_mult = 1.0
	var logistics_bonus = 0.0
	var sell_mult = 1.0
	
	if modifier_mgr != null:
		miner_speed_mult += modifier_mgr.get_bonus("miner_speed")
		factory_speed_mult += modifier_mgr.get_bonus("factory_speed")
		logistics_bonus = modifier_mgr.get_bonus("logistics_transfer")
		sell_mult += modifier_mgr.get_bonus("sell_price_mult")
		
	# 1. Tick all building processes
	for b in _buildings_list:
		var speed_mult = miner_speed_mult if b.type.begins_with("miner") else factory_speed_mult
		b.tick(delta, speed_mult)
		
	# Reset transfer activity flags on connections
	for conn in connections:
		conn["is_active"] = false
		conn["flow_rate"] = 0.0
		
	# 2. Distribute resources along connections (Round-Robin per source building)
	var transfer_rate = 1.0 * (1.0 + logistics_bonus)

	for outgoing_group in _building_outgoing_conns:
		var num_conns = outgoing_group.size()
		if num_conns == 0:
			continue
			
		var from_b_first: BuildingData = outgoing_group[0][0]
		var start_conn_idx = from_b_first.last_outgoing_conn_index % num_conns
		
		for c_step in range(num_conns):
			var conn_idx = (start_conn_idx + c_step) % num_conns
			var cache = outgoing_group[conn_idx]
			
			var from_b: BuildingData = cache[0]
			var to_b: BuildingData = cache[1]
			var conn_dict: Dictionary = cache[2]
			var from_port: int = cache[3]
			var to_port: int = cache[4]
			
			var resources: Array[String] = []
			if to_b.type == "portal" or to_b.type.begins_with("splitter"):
				for res in from_b.outputs.keys():
					if res.begins_with("_"): continue
					if to_b.type == "portal":
						if to_b.input_limits.has(res):
							resources.append(res)
					else:
						to_b.inputs[res] = to_b.inputs.get(res, 0.0)
						to_b.input_limits[res] = maxf(to_b.input_limits.get(res, 20.0), 20.0)
						resources.append(res)
			elif from_b.type.begins_with("splitter"):
				for res in from_b.outputs.keys():
					if res.begins_with("_"): continue
					if to_b.inputs.has(res) or to_b.active_recipe.get("inputs", {}).has(res):
						to_b.inputs[res] = to_b.inputs.get(res, 0.0)
						to_b.input_limits[res] = maxf(to_b.input_limits.get(res, 20.0), 20.0)
						resources.append(res)
			else:
				for res in from_b.outputs.keys():
					if res.begins_with("_"): continue
					if to_b.inputs.has(res):
						resources.append(res)
			
			if resources.is_empty():
				continue

			var cur_progress = float(conn_dict.get("transfer_progress", 0.0)) + transfer_rate * delta
			var possible_units = floori(cur_progress)
			
			if possible_units >= 1:
				var total_transferred = 0
				var num_res = resources.size()
				var start_res_idx = int(conn_dict.get("last_res_index", 0)) % num_res
				
				for i in range(num_res):
					var res_idx = (start_res_idx + i) % num_res
					var res = resources[res_idx]
					
					var available_units = floori(from_b.outputs.get(res, 0.0))
					if available_units <= 0:
						continue
						
					var target_current = to_b.inputs.get(res, 0.0)
					var target_limit = to_b.input_limits.get(res, 20.0)
					var space_units = floori(target_limit - target_current)
					
					if space_units <= 0:
						continue
						
					var units_to_move = min(possible_units - total_transferred, min(available_units, space_units))
					if units_to_move > 0:
						from_b.outputs[res] -= float(units_to_move)
						to_b.inputs[res] += float(units_to_move)
						total_transferred += units_to_move
						conn_dict["is_active"] = true
						conn_dict["flow_rate"] = transfer_rate
						conn_dict["last_res_index"] = (res_idx + 1) % num_res
						from_b.last_outgoing_conn_index = (conn_idx + 1) % num_conns
						resource_transferred.emit(from_b.id, from_port, to_b.id, to_port, res, float(units_to_move), transfer_rate)
						if total_transferred >= possible_units:
							break
							
				cur_progress -= float(total_transferred)
						
			conn_dict["transfer_progress"] = minf(cur_progress, 1.0)
			
	# 3. Harvest global credits from outputs, process Portal deliveries & collect crafted Artifacts
	if resource_mgr != null:
		for b in _credits_producers:
			var amt = b.outputs.get("credits", 0.0)
			if amt > 0.0:
				resource_mgr.add_resource("credits", amt * sell_mult)
				b.outputs["credits"] = 0.0
				
	if milestones_mgr != null:
		for p in _portals:
			for res in p.inputs.keys():
				if not res.begins_with("_"):
					var amt = float(p.inputs[res])
					milestones_mgr.submit_portal_resource(res, amt)

	if artifacts_mgr != null:
		for b in _buildings_list:
			for res_name in b.outputs.keys():
				if not res_name.begins_with("_") and artifacts_mgr.artifact_configs.has(res_name):
					var amt = int(b.outputs[res_name])
					if amt > 0:
						artifacts_mgr.add_artifact_to_inventory(res_name, amt)
						b.outputs[res_name] = 0.0

## Serializes the entire network.
func to_dict() -> Dictionary:
	var serialized_buildings = []
	for b in _buildings_list:
		serialized_buildings.append(b.to_dict())
		
	return {
		"next_id": next_id,
		"buildings": serialized_buildings,
		"connections": connections.duplicate(true)
	}

## Deserializes and restores the factory network.
static func from_dict(dict: Dictionary) -> FactoryNetwork:
	var net = FactoryNetwork.new()
	net.next_id = int(dict.get("next_id", 1))
	
	var serialized_buildings = dict.get("buildings", [])
	for b_dict in serialized_buildings:
		var b = BuildingData.from_dict(b_dict)
		net.buildings[b.id] = b
		for cell in b.get_occupied_cells():
			net.grid[cell] = b.id
		
	net.connections = []
	var raw_conns = dict.get("connections", [])
	for conn in raw_conns:
		net.connections.append({
			"from_id": int(conn.get("from_id", 0)),
			"from_port": int(conn.get("from_port", 0)),
			"to_id": int(conn.get("to_id", 0)),
			"to_port": int(conn.get("to_port", 0))
		})
		
	net.rebuild_caches()
	return net
