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
var temp_visited_splitters: Dictionary = {}
var altars: Array[BuildingData] = []

func rebuild_caches() -> void:
	buildings_list.clear()
	altars.clear()

	for building_instance in buildings.values():
		buildings_list.append(building_instance)
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
			
			var possible_outputs: Array = []
			var out_slots = from_building.shared_slots if from_building.config.buffer_mode == "shared" else from_building.output_slots
			for slot in out_slots:
				for tag in slot.accepted_tags:
					if not possible_outputs.has(tag):
						possible_outputs.append(tag)
						
			var in_slots = to_building.shared_slots if to_building.config.buffer_mode == "shared" else to_building.input_slots
						
			for output_tag in possible_outputs:
				var is_match = false
				if to_building.config.process_logic == "passthrough":
					is_match = true
				else:
					for in_slot in in_slots:
						if in_slot.accepted_tags.is_empty():
							is_match = true
							break
						for in_tag in in_slot.accepted_tags:
							if output_tag == in_tag or ItemTagSystem.has_tag(output_tag, in_tag):
								is_match = true
								break
						if is_match:
							break
				
				if is_match:
					cached_resources.append(output_tag)

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
