class_name FactoryNetwork
extends RefCounted

## Manages the factory graph, connections, and resource distribution simulation.
## Highly optimized using pre-cached references for high-speed offline simulation.

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

## Adds a new building to the network.
func add_building(type: String, pos: Vector2i, recipe: Dictionary) -> BuildingData:
	if grid.has(pos):
		printerr("Grid position already occupied: ", pos)
		return null
		
	var b_id = next_id
	next_id += 1
	
	var building = BuildingData.new(b_id, type, pos, recipe)
	buildings[b_id] = building
	grid[pos] = b_id
	
	if not batch_mode:
		rebuild_caches()
	return building

## Removes a building and all its connections.
func remove_building(b_id: int) -> void:
	if not buildings.has(b_id):
		return
		
	var building = buildings[b_id]
	grid.erase(building.grid_position)
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
		
	# Check if connection already exists
	for conn in connections:
		if conn["from_id"] == from_id and conn["to_id"] == to_id:
			return false
			
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
	for b in buildings.values():
		_buildings_list.append(b)
		if b.outputs.has("credits"):
			_credits_producers.append(b)
		
	# 2. Rebuild connection cache with direct object references and intersecting resources
	_connection_cache.clear()
	for conn in connections:
		var from_b = buildings.get(conn["from_id"])
		var to_b = buildings.get(conn["to_id"])
		
		if from_b and to_b:
			# Find which resources can be transferred from source outputs to target inputs
			var shared_resources: Array[String] = []
			for out_res in from_b.outputs:
				if to_b.inputs.has(out_res):
					shared_resources.append(out_res)
					
			if not shared_resources.is_empty():
				_connection_cache.append([from_b, to_b, shared_resources])

## Performs a single step of the simulation network (delta in seconds, usually 1.0).
func tick(delta: float = 1.0, economy: EconomyManager = null) -> void:
	# 1. Tick all building processes
	for b in _buildings_list:
		b.tick(delta)
		
	# 2. Distribute resources along connections
	# Default transfer rate: 5.0 items per tick (adjust as needed)
	var transfer_rate = 5.0
	var max_transfer = transfer_rate * delta
	
	for cache in _connection_cache:
		var from_b: BuildingData = cache[0]
		var to_b: BuildingData = cache[1]
		var resources: Array = cache[2]
		
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
			
			from_b.outputs[res] -= amount
			to_b.inputs[res] += amount
			
	# 3. Harvest global credits from outputs directly to economy
	if economy != null:
		for b in _credits_producers:
			var amt = b.outputs.get("credits", 0.0)
			if amt > 0.0:
				economy.add_resource("credits", amt)
				b.outputs["credits"] = 0.0

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
	net.next_id = dict.get("next_id", 1)
	
	var serialized_buildings = dict.get("buildings", [])
	for b_dict in serialized_buildings:
		var b = BuildingData.from_dict(b_dict)
		net.buildings[b.id] = b
		net.grid[b.grid_position] = b.id
		
	net.connections = dict.get("connections", []).duplicate(true)
	net.rebuild_caches()
	return net
