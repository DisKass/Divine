class_name FactoryState
extends RefCounted

## Container for the global factory state and performance caches.
## Manipulated by Data-Driven Systems (GridSystem, FlowSystem, ProductionSystem).

signal resource_transferred(from_id: int, from_port: int, to_id: int, to_port: int, resource_name: String, amount: float, transfer_rate: float)

# Main Data
var buildings: Dictionary = {}
var grid: Dictionary = {}
var connections: Array = []
var next_id: int = 1
var batch_mode: bool = false
var building_counts: Dictionary = {}

# Performance Caches
var buildings_list: Array[BuildingData] = []
var connection_cache: Array = []
var building_outgoing_connections: Array = []
var building_outgoing_connections_map: Dictionary = {}
var credits_producers: Array[BuildingData] = []
var portals: Array[BuildingData] = []
var altars: Array[BuildingData] = []
var temp_visited_splitters: Dictionary = {}

func rebuild_caches() -> void:
	buildings_list.clear()
	credits_producers.clear()
	portals.clear()
	altars.clear()

	for building_instance in buildings.values():
		buildings_list.append(building_instance)
		if building_instance.outputs.has("credits"):
			credits_producers.append(building_instance)
		if building_instance.type == "portal":
			portals.append(building_instance)
		if building_instance.type == "artifact_altar":
			altars.append(building_instance)

	connection_cache.clear()
	var grouped_by_from: Dictionary = {}

	for connection_data in connections:
		var from_building = buildings.get(connection_data["from_id"])
		var to_building = buildings.get(connection_data["to_id"])
		var from_port = int(connection_data.get("from_port", 0))
		var to_port = int(connection_data.get("to_port", 0))

		if from_building and to_building:
			var cached_resources: Array[String] = []
			for resource_name in from_building.outputs.keys():
				if resource_name.begins_with("_"):
					continue
				if to_building.is_portal:
					if to_building.input_limits.has(resource_name):
						cached_resources.append(resource_name)
				elif to_building.is_splitter:
					cached_resources.append(resource_name)
				elif from_building.is_splitter:
					if to_building.inputs.has(resource_name) or to_building.active_recipe.get("inputs", {}).has(resource_name):
						to_building.inputs[resource_name] = to_building.inputs.get(resource_name, 0.0)
						to_building.input_limits[resource_name] = maxf(to_building.input_limits.get(resource_name, 20.0), 20.0)
						cached_resources.append(resource_name)
				else:
					if to_building.inputs.has(resource_name):
						cached_resources.append(resource_name)

			var cache_entry = [from_building, to_building, connection_data, from_port, to_port, cached_resources]
			connection_cache.append(cache_entry)
			if not grouped_by_from.has(from_building.id):
				grouped_by_from[from_building.id] = []
			grouped_by_from[from_building.id].append(cache_entry)

	building_outgoing_connections_map = grouped_by_from
	building_outgoing_connections = grouped_by_from.values()

func to_dict() -> Dictionary:
	var serialized_buildings = []
	for building_instance in buildings_list:
		serialized_buildings.append(building_instance.to_dict())

	return {
		"next_id": next_id,
		"buildings": serialized_buildings,
		"connections": connections.duplicate(true),
		"building_counts": building_counts.duplicate()
	}

static func from_dict(data_dictionary: Dictionary) -> FactoryState:
	var state = FactoryState.new()
	state.next_id = int(data_dictionary.get("next_id", 1))

	var serialized_buildings = data_dictionary.get("buildings", [])
	for building_dictionary in serialized_buildings:
		var building_instance = BuildingData.from_dict(building_dictionary)
		state.buildings[building_instance.id] = building_instance
		for cell in building_instance.get_occupied_cells():
			state.grid[cell] = building_instance.id

	state.connections = []
	var raw_connections = data_dictionary.get("connections", [])
	for connection_data in raw_connections:
		state.connections.append({
			"from_id": int(connection_data.get("from_id", 0)),
			"from_port": int(connection_data.get("from_port", 0)),
			"to_id": int(connection_data.get("to_id", 0)),
			"to_port": int(connection_data.get("to_port", 0))
		})

	state.rebuild_caches()
	return state

func load_from_dict(data_dictionary: Dictionary) -> void:
	next_id = int(data_dictionary.get("next_id", 1))
	buildings.clear()
	grid.clear()
	connections.clear()

	var serialized_buildings = data_dictionary.get("buildings", [])
	for building_dictionary in serialized_buildings:
		var building_instance = BuildingData.from_dict(building_dictionary)
		buildings[building_instance.id] = building_instance
		for cell in building_instance.get_occupied_cells():
			grid[cell] = building_instance.id

	var raw_connections = data_dictionary.get("connections", [])
	for connection_data in raw_connections:
		connections.append({
			"from_id": int(connection_data.get("from_id", 0)),
			"from_port": int(connection_data.get("from_port", 0)),
			"to_id": int(connection_data.get("to_id", 0)),
			"to_port": int(connection_data.get("to_port", 0))
		})

	building_counts = data_dictionary.get("building_counts", {}).duplicate()

	rebuild_caches()
