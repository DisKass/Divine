class_name GridSystem
extends RefCounted

## Handles spatial placement, collisions, and grid occupancy.
## Operates on FactoryState.

static func is_area_free(state: FactoryState, top_left: Vector2i, size_in_cells: Vector2i, ignore_building_id: int = 0) -> bool:
	for x in range(size_in_cells.x):
		for y in range(size_in_cells.y):
			var cell = top_left + Vector2i(x, y)
			if state.grid.has(cell):
				var occupied_id = state.grid[cell]
				if occupied_id != ignore_building_id:
					return false
	return true

static func add_building(state: FactoryState, building_type: String, grid_position: Vector2i, recipe_data: Dictionary) -> BuildingData:
	var default_size = BuildingData.get_default_size(building_type)
	if not is_area_free(state, grid_position, default_size):
		printerr("Grid position already occupied for area: ", grid_position, " size: ", default_size)
		return null

	var building_id = state.next_id
	state.next_id += 1

	var building_instance = BuildingData.new(building_id, building_type, grid_position, recipe_data)
	state.buildings[building_id] = building_instance
	for cell in building_instance.get_occupied_cells():
		state.grid[cell] = building_id

	if not state.batch_mode:
		state.rebuild_caches()
	return building_instance

static func move_building(state: FactoryState, building_id: int, new_grid_position: Vector2i) -> bool:
	if not state.buildings.has(building_id):
		return false

	var building_instance = state.buildings[building_id]
	if not is_area_free(state, new_grid_position, building_instance.size_in_cells, building_id):
		return false

	for cell in building_instance.get_occupied_cells():
		state.grid.erase(cell)

	building_instance.grid_position = new_grid_position
	for cell in building_instance.get_occupied_cells():
		state.grid[cell] = building_id

	if not state.batch_mode:
		state.rebuild_caches()
	return true

static func remove_building(state: FactoryState, building_id: int) -> void:
	if not state.buildings.has(building_id):
		return

	var building_instance = state.buildings[building_id]
	for cell in building_instance.get_occupied_cells():
		state.grid.erase(cell)
	state.buildings.erase(building_id)

	# Remove any connections associated with this building
	var connections_to_keep: Array = []
	for connection_data in state.connections:
		if connection_data["from_id"] != building_id and connection_data["to_id"] != building_id:
			connections_to_keep.append(connection_data)
	state.connections = connections_to_keep

	if not state.batch_mode:
		state.rebuild_caches()
