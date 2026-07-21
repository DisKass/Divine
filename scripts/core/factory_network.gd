class_name FactoryNetwork
extends RefCounted

## Manages the factory graph, connections, and resource distribution simulation.
## Highly optimized using pre-cached references for high-speed offline simulation.

signal resource_transferred(from_id: int, to_id: int, resource_name: String, amount: float)

# Map of building ID -> BuildingData
var buildings: Dictionary = {}
# Map of Vector2i -> building ID (for collision checks)
var grid: Dictionary = {}
# List of connections: Array of Dictionary { "from_id": int, "to_id": int }
var connections: Array = []

# Next building ID to assign
var next_id: int = 1

# Batch Mode flag
var batch_mode: bool = false

# Performance Caches (rebuilt when network structure changes)
var _buildings_list: Array[BuildingData] = []
var _connection_cache: Array = [] # Array of cached connection structures: [from_building, to_building, resource_list]
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


## Adds a connection from one building to another.
func add_connection(from_id: int, to_id: int) -> bool:
	if from_id == to_id:
		return false # No self-connections
		
	if not buildings.has(from_id) or not buildings.has(to_id):
		return false
		
	var from_b = buildings[from_id]
	var to_b = buildings[to_id]
	
	# Verify that the output of from_b matches at least one input of to_b
	var has_matching_resource = false
	if to_b.type == "portal":
		for out_res in from_b.outputs:
			to_b.inputs[out_res] = to_b.inputs.get(out_res, 0.0)
			to_b.input_limits[out_res] = 9999.0
			has_matching_resource = true
	else:
		for out_res in from_b.outputs:
			if to_b.inputs.has(out_res):
				has_matching_resource = true
				break
			
	if not has_matching_resource:
		return false
		
	# Remove any existing connection originating from from_id (only one output link allowed)
	var i = 0
	while i < connections.size():
		if connections[i]["from_id"] == from_id:
			connections.remove_at(i)
		else:
			i += 1
			
	connections.append({
		"from_id": from_id,
		"to_id": to_id
	})
	
	if not batch_mode:
		rebuild_caches()
	return true

## Removes a connection.
func remove_connection(from_id: int, to_id: int) -> void:
	var index_to_remove = -1
	for i in range(connections.size()):
		var conn = connections[i]
		if conn["from_id"] == from_id and conn["to_id"] == to_id:
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
		
	# 2. Rebuild connection cache with direct object references and intersecting resources
	_connection_cache.clear()
	for conn in connections:
		var from_b = buildings.get(conn["from_id"])
		var to_b = buildings.get(conn["to_id"])
		
		if from_b and to_b:
			# Find which resources can be transferred from source outputs to target inputs
			var shared_resources: Array[String] = []
			if to_b.type == "portal":
				for out_res in from_b.outputs:
					to_b.inputs[out_res] = to_b.inputs.get(out_res, 0.0)
					to_b.input_limits[out_res] = 9999.0
					shared_resources.append(out_res)
			else:
				for out_res in from_b.outputs:
					if to_b.inputs.has(out_res):
						shared_resources.append(out_res)
					
			if not shared_resources.is_empty():
				_connection_cache.append([from_b, to_b, shared_resources, conn])

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
		
	# 2. Distribute resources along connections
	# Default transfer rate: 1.0 item per second base
	var transfer_rate = 1.0 * (1.0 + logistics_bonus)
	var max_transfer = transfer_rate * delta

	for cache in _connection_cache:
		var from_b: BuildingData = cache[0]
		var to_b: BuildingData = cache[1]
		var resources: Array = cache[2]
		var conn_dict: Dictionary = cache[3]
		
		for res in resources:
			var available = from_b.outputs.get(res, 0.0)
			if available <= 0.0:
				continue
				
			var target_current = to_b.inputs.get(res, 0.0)
			var target_limit = to_b.input_limits.get(res, 20.0)
			var space = target_limit - target_current
			
			if space <= 0.0:
				continue
				
			# Transfer limit is the minimum of what is available, what can fit, and max transfer rate
			var amount = minf(available, minf(space, max_transfer))
			if amount > 0.0:
				from_b.outputs[res] -= amount
				to_b.inputs[res] += amount
				conn_dict["is_active"] = true
				conn_dict["flow_rate"] = transfer_rate
				resource_transferred.emit(from_b.id, to_b.id, res, amount)
			
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
				var amt = float(p.inputs[res])
				if amt > 0.0:
					milestones_mgr.submit_portal_resource(res, amt)
					p.inputs[res] = 0.0

	if artifacts_mgr != null:
		for altar in _altars:
			for res_name in altar.outputs.keys():
				if artifacts_mgr.artifact_configs.has(res_name):
					var amt = int(altar.outputs[res_name])
					if amt > 0:
						artifacts_mgr.add_artifact_to_inventory(res_name, amt)
						altar.outputs[res_name] = 0.0

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
			"to_id": int(conn.get("to_id", 0))
		})
		
	net.rebuild_caches()
	return net

