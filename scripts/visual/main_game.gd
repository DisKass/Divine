extends Node2D
class_name MainGame

## Main Game Controller. Coordinates simulation, UI, mouse modes, and save management.

enum MouseMode { INSPECT, BUILD, LINK, DEMOLISH, COPY_BUILD }

# Settings
@export var cell_size: int = 32

# Mode State
var current_mode: MouseMode = MouseMode.INSPECT
var selected_build_type: String = ""
var selected_building_id: int = 0
var link_source_id: int = 0

# Copy State
var copy_data: Dictionary = {} # { "buildings": Array, "connections": Array, "bounds_size": Vector2i, "total_cost": Dictionary }

# Core Managers
var state: GameState
var ticker: SimulationTicker
var input_controller: InputController

# Visual maps: building_id -> BuildingVisual
var visuals_map: Dictionary = {}

# Node references
var camera: GameCamera
var grid_renderer: GridRenderer
var connection_renderer: ConnectionRenderer
var building_renderer: BuildingRenderer
var buildings_container: Node2D
var build_preview: PanelContainer

var _needs_save: bool = false
var _time_since_last_save: float = 0.0

# Input Controller


# UI References (Instantiated from scenes)
var hud: HUD
var inspector_panel: InspectorPanel
var gd_panel: GDPanel
var popup_dialog: AcceptDialog

# Default recipes for placing buildings, populated dynamically from Recipes database
var default_recipes: Dictionary = {}

# Auto-save timer
var save_timer: float = 0.0
const AUTO_SAVE_INTERVAL: float = 30.0

func _ready() -> void:
	# Populate default recipes from Recipes database
	for b_type in Recipes.DATA:
		default_recipes[b_type] = Recipes.DATA[b_type][0]

	# 1. Setup Camera and drawing nodes
	camera = GameCamera.new()
	camera.position = Vector2.ZERO
	add_child(camera)
	
	grid_renderer = GridRenderer.new()
	grid_renderer.cell_size = cell_size
	add_child(grid_renderer)
	
	connection_renderer = ConnectionRenderer.new()
	add_child(connection_renderer)
	
	buildings_container = Node2D.new()
	add_child(buildings_container)
	
	building_renderer = BuildingRenderer.new()
	add_child(building_renderer)
	
	# 2. Setup build preview phantom
	_create_build_preview()
	
	# 3. Setup GUI Layout using external scenes
	var hud_scene = preload("res://scenes/hud.tscn")
	hud = hud_scene.instantiate()
	add_child(hud)
	hud.mode_changed.connect(_on_hud_mode_changed)
	hud.reset_game_pressed.connect(_on_reset_pressed)
	
	var inspector_scene = preload("res://scenes/inspector_panel.tscn")
	inspector_panel = inspector_scene.instantiate()
	hud.add_child(inspector_panel)
	inspector_panel.recipe_selected.connect(_on_recipe_selected)
	
	# 3.5. Setup Input Controller
	input_controller = InputController.new()
	input_controller.cell_size = cell_size
	add_child(input_controller)
	input_controller.building_clicked.connect(_on_input_building_clicked)
	input_controller.building_right_clicked.connect(_on_input_building_right_clicked)
	input_controller.empty_space_clicked.connect(_on_input_empty_space_clicked)
	input_controller.building_move_completed.connect(_on_input_building_move_completed)
	input_controller.link_mode_cancelled.connect(_on_input_link_mode_cancelled)
	input_controller.selection_changed.connect(_on_input_selection_changed)
	input_controller.demolish_requested.connect(_on_input_demolish_requested)
	input_controller.copy_requested.connect(_on_input_copy_requested)
	input_controller.copy_placement_confirmed.connect(_on_input_copy_placement_confirmed)
	input_controller.copy_placement_cancelled.connect(_on_input_copy_placement_cancelled)
	
	# 4. Load or Init Core Simulation
	_initialize_game()
	
	# 5. Setup GD Debug Panel
	gd_panel = GDPanel.new()
	hud.add_child(gd_panel)
	hud.gd_panel = gd_panel
	gd_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	gd_panel.visible = false
	gd_panel.setup(state, self)
	
	# Connect to tick signal to update UI
	ticker.tick_completed.connect(_on_simulation_tick)
	
	# Force initial UI update
	_update_ui()

func _initialize_game() -> void:
	state = GameState.new()
	
	if not SaveSystem.load_game(state):
		ResourceSystem.add_resource(state, "credits", 85.0)
		
	ticker = SimulationTicker.new(state)
	
	for b_id in state.factory.buildings:
		_create_building_visual(state.factory.buildings[b_id])
		
	ticker.time_accumulator = 0.0

	state.milestone_completed.connect(func(_t, _d):
		if state:
			FlowSystem.sync_portal_inputs(state)
			state.factory.rebuild_caches()
	)
	state.milestone_reset.connect(func():
		if state:
			FlowSystem.sync_portal_inputs(state)
			state.factory.rebuild_caches()
	)
	FlowSystem.sync_portal_inputs(state)

	building_renderer.setup(visuals_map, camera, cell_size, hud)
	connection_renderer.setup(state, visuals_map, camera)
	if is_instance_valid(input_controller):
		input_controller.setup(camera, state, visuals_map, build_preview, building_renderer, connection_renderer)

func _reset(clear_save: bool = false) -> void:
	if clear_save:
		SaveSystem.delete_save()
	
	for v in visuals_map.values():
		if is_instance_valid(v):
			v.queue_free()
	visuals_map.clear()
	
	if is_instance_valid(input_controller):
		input_controller.set_selected_buildings([])
		input_controller.copy_preview_info.clear()
		
	selected_building_id = 0
	inspector_panel.visible = false
	
	_initialize_game()
	
	if is_instance_valid(building_renderer):
		building_renderer.setup(visuals_map, camera, cell_size, hud)
	if is_instance_valid(connection_renderer):
		connection_renderer.setup(state, visuals_map, camera)
	if is_instance_valid(input_controller):
		input_controller.setup(camera, state, visuals_map, build_preview, building_renderer, connection_renderer)
	
	for b_id in state.factory.buildings:
		_create_building_visual(state.factory.buildings[b_id])

func request_save() -> void:
	_needs_save = true

func _process(delta: float) -> void:
	# Run simulation ticker ticks
	ticker.process_realtime(delta)
	
	_time_since_last_save += delta
	if _needs_save and _time_since_last_save >= 5.0:
		SaveSystem.save_game(state)
		_needs_save = false
		_time_since_last_save = 0.0
	
	# Color red if blocked, green if empty and affordable (BUILD preview)
	if current_mode == MouseMode.BUILD and is_instance_valid(input_controller):
		var grid_pos = input_controller._get_build_placement_grid_pos(selected_build_type)
		var b_size = BuildingData.get_default_size(selected_build_type)
		var style = build_preview.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			if not GridSystem.is_area_free(state.factory, grid_pos, b_size):
				style.border_color = Color(0.9, 0.25, 0.25, 0.8) # Red (blocked)
				style.bg_color = Color(0.9, 0.25, 0.25, 0.15)
			elif not BuildingSystem.can_afford(state, selected_build_type):
				style.border_color = Color(0.9, 0.6, 0.1, 0.8) # Orange (unaffordable)
				style.bg_color = Color(0.9, 0.6, 0.1, 0.1)
			else:
				style.border_color = Color(0.2, 0.85, 0.4, 0.8) # Green (OK)
				style.bg_color = Color(0.2, 0.85, 0.4, 0.15)
				
	# Update Copy Placement Preview (MouseMode.COPY_BUILD)
	elif current_mode == MouseMode.COPY_BUILD and is_instance_valid(input_controller) and not copy_data.is_empty():
		var origin_grid = input_controller._get_copy_placement_origin_grid()
		var b_list = copy_data.get("buildings", [])
		var is_valid = true
		for b in b_list:
			var rel_pos: Vector2i = b["relative_pos"]
			var b_size: Vector2i = b["size"]
			var cell_pos = origin_grid + rel_pos
			if not GridSystem.is_area_free(state.factory, cell_pos, b_size):
				is_valid = false
				break
				
		var total_cost = copy_data.get("total_cost", {})
		var can_afford = ResourceSystem.can_afford(state, total_cost) if not state.free_buildings_mode else true
		
		input_controller.copy_preview_info = {
			"buildings": b_list,
			"bounds_size": copy_data.get("bounds_size", Vector2i(1, 1)),
			"origin_grid": origin_grid,
			"is_valid": is_valid and can_afford
		}
		
		inspector_panel.update_multi_inspector(b_list.size(), total_cost, can_afford)
			
	# Auto-save
	save_timer += delta
	if save_timer >= AUTO_SAVE_INTERVAL:
		save_timer = 0.0
		request_save()

func _handle_inspect(building_id: int) -> void:
	# Deselect current
	if selected_building_id != 0 and visuals_map.has(selected_building_id):
		visuals_map[selected_building_id].is_selected = false
		
	selected_building_id = building_id
	
	if selected_building_id != 0 and visuals_map.has(selected_building_id):
		visuals_map[selected_building_id].is_selected = true
		_update_inspector()
	else:
		inspector_panel.visible = false
		
	if is_instance_valid(building_renderer):
		building_renderer.mark_borders_dirty()

func _handle_build(grid_pos: Vector2i) -> void:
	var default_rec = default_recipes.get(selected_build_type, {})
	var b_size = BuildingData.get_default_size(selected_build_type)
	if not GridSystem.is_area_free(state.factory, grid_pos, b_size):
		return # Blocked

	if not BuildingSystem.can_afford(state, selected_build_type):
		return # Cannot afford
		
	# Process purchase
	if BuildingSystem.buy_building(state, selected_build_type):
		var recipe = default_rec.duplicate(true) if not default_rec.is_empty() else {}
		var b_data = BuildingSystem.place_building(state, selected_build_type, grid_pos)
		if b_data and not recipe.is_empty():
			b_data.set_recipe(recipe)
		if b_data and selected_build_type == "portal":
			FlowSystem.sync_portal_inputs(state)
		if b_data:
			_create_building_visual(b_data)
		_update_ui()
		
		# If Shift is NOT held, cancel build selection after 1 placement
		if not Input.is_key_pressed(KEY_SHIFT):
			_set_mouse_mode(MouseMode.INSPECT)

var link_source_port: int = 0

func _handle_link(building_id: int) -> void:
	if building_id == 0:
		return # Must click a building
		
	if link_source_id == 0:
		# Set source
		link_source_id = building_id
		link_source_port = 0
		visuals_map[link_source_id].is_selected = true
		if is_instance_valid(input_controller):
			input_controller.link_source_id = link_source_id
			input_controller.link_source_port = link_source_port
	else:
		# We clicked the target building
		if link_source_id != building_id:
			var target_port = 0
			var source_b = state.factory.buildings.get(link_source_id)
			var target_b = state.factory.buildings.get(building_id)
			var target_vis = visuals_map.get(building_id)
			
			if source_b and target_b:
				var source_res = ""
				var out_keys = []
				for k in source_b.outputs.keys():
					if not k.begins_with("_"):
						out_keys.append(k)
				if not source_b.active_recipe.is_empty():
					var rec_outs = source_b.active_recipe.get("outputs", {}).keys()
					for k in rec_outs:
						if not out_keys.has(k):
							out_keys.append(k)
				if out_keys.size() > 0:
					var p_idx = clamp(link_source_port, 0, out_keys.size() - 1)
					source_res = out_keys[p_idx]
					
				if source_res != "" and is_instance_valid(target_vis):
					target_port = target_vis.get_input_port_for_resource(source_res)
					
			FlowSystem.add_connection(state.factory, link_source_id, building_id, link_source_port, target_port)
			if is_instance_valid(connection_renderer):
				connection_renderer.mark_lines_dirty()
		_set_mouse_mode(MouseMode.INSPECT)

func _handle_demolish(building_id: int) -> void:
	if building_id == 0:
		return
		
	var building = state.factory.buildings.get(building_id)
	if building:
		BuildingSystem.demolish_building(state, building_id)
		
		# Remove from visual system
		if visuals_map.has(building_id):
			visuals_map[building_id].queue_free()
			visuals_map.erase(building_id)
		
		# Deselect if needed
		if selected_building_id == building_id:
			selected_building_id = 0
			inspector_panel.visible = false
			
		_update_ui()

func _create_building_visual(b_data: BuildingData) -> void:
	var visual = BuildingVisual.new()
	visuals_map[b_data.id] = visual
	buildings_container.add_child(visual)
	visual.setup(b_data, cell_size)

func _create_build_preview() -> void:
	build_preview = PanelContainer.new()
	build_preview.custom_minimum_size = Vector2.ZERO
	build_preview.visible = false
	build_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.85, 0.4, 0.15)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.85, 0.4, 0.8)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	build_preview.add_theme_stylebox_override("panel", style)
	
	add_child(build_preview)

func _set_mouse_mode(mode: MouseMode, build_type: String = "") -> void:
	# Clean up previous mode state
	if link_source_id != 0 and visuals_map.has(link_source_id):
		visuals_map[link_source_id].is_selected = false
	link_source_id = 0
	link_source_port = 0
	
	current_mode = mode
	selected_build_type = build_type
	
	# Show/hide build preview
	build_preview.visible = (current_mode == MouseMode.BUILD)
	if current_mode != MouseMode.COPY_BUILD:
		copy_data.clear()
		if is_instance_valid(input_controller):
			input_controller.copy_preview_info.clear()
	
	# Sync state with InputController
	if is_instance_valid(input_controller):
		input_controller.current_mode = current_mode as int
		input_controller.selected_build_type = selected_build_type
		input_controller.link_source_id = link_source_id
		input_controller.link_source_port = link_source_port
		
	# Refresh UI
	_update_ui()

func _on_hud_mode_changed(mode: int, build_type: String) -> void:
	_set_mouse_mode(mode as MouseMode, build_type)

func _on_simulation_tick(_ticks: int) -> void:
	var any_text_updated = false
	for vis in visuals_map.values():
		if is_instance_valid(vis) and vis.visible:
			if vis.update_text_cache():
				any_text_updated = true
	if is_instance_valid(building_renderer) and any_text_updated:
		building_renderer.request_static_redraw()
	_update_ui()
	if selected_building_id != 0:
		_update_inspector()

func _update_ui() -> void:
	# Calculate credits income rate
	var credits_per_tick = 0.0
	for b in state.factory.buildings_list:
		if b.type == "seller" and not b.active_recipe.is_empty():
			var dur = float(b.active_recipe.get("duration", 1.0))
			var amt = b.active_recipe.get("outputs", {}).get("credits", 0.0)
			credits_per_tick += amt / dur
			
	# Will refactor HUD soon, pass the managers for now
	if hud.has_method("update_hud_new"):
		hud.update_hud_new(state, credits_per_tick, current_mode as int, selected_build_type)
	else:
		pass # Ignore old HUD method until refactored

func _update_inspector() -> void:
	var b_data = state.factory.buildings.get(selected_building_id)
	if inspector_panel.has_method("update_inspector_new"):
		inspector_panel.update_inspector_new(b_data, state)
	else:
		pass # Ignore old inspector panel method until refactored

func _on_recipe_selected(idx: int) -> void:
	var b_data = state.factory.buildings.get(selected_building_id)
	if b_data == null:
		return
	var possible_recipes = Recipes.DATA.get(b_data.type, [])
	if idx >= 0 and idx < possible_recipes.size():
		var new_recipe = possible_recipes[idx].duplicate(true)
		b_data.set_recipe(new_recipe)
		state.factory.rebuild_caches()
		_update_inspector()
		request_save()

# --- Input Controller Handlers ---

func _on_input_building_clicked(building_id: int) -> void:
	if current_mode == MouseMode.LINK:
		_handle_link(building_id)
	elif current_mode == MouseMode.DEMOLISH:
		_handle_demolish(building_id)
	else:
		_handle_inspect(building_id)

func _on_input_building_right_clicked(building_id: int, port_index: int = 0) -> void:
	_set_mouse_mode(MouseMode.LINK)
	link_source_id = building_id
	link_source_port = port_index
	visuals_map[link_source_id].is_selected = true
	if is_instance_valid(input_controller):
		input_controller.link_source_id = link_source_id
		input_controller.link_source_port = port_index

func _on_input_empty_space_clicked(grid_pos: Vector2i) -> void:
	if current_mode == MouseMode.BUILD:
		_handle_build(grid_pos)
	else:
		_handle_inspect(0)

func _on_input_building_move_completed() -> void:
	request_save()

func _on_input_link_mode_cancelled() -> void:
	_set_mouse_mode(MouseMode.INSPECT)

func _on_input_selection_changed(ids: Array[int]) -> void:
	if ids.size() == 1:
		_handle_inspect(ids[0])
	elif ids.size() > 1:
		selected_building_id = 0
		var total_cost: Dictionary = {}
		var sim_counts: Dictionary = BuildingSystem.get_building_counts(state)
		for b_id in ids:
			var b_data = state.factory.buildings.get(b_id)
			if b_data:
				var type = b_data.type
				var count = sim_counts.get(type, 0)
				var config: BuildingCostData = BuildingSystem.cost_configs.get(type)
				if config != null:
					var cost = {}
					if count == 0:
						for res in config.base_costs: cost[res] = float(config.base_costs[res])
					else:
						var factor = pow(config.multiplier, count - 1)
						for res in config.first_paid_costs: cost[res] = snappedf(float(config.first_paid_costs[res]) * factor, 0.1)
					for res in cost:
						total_cost[res] = total_cost.get(res, 0.0) + cost[res]
				sim_counts[type] = count + 1
		var can_afford = ResourceSystem.can_afford(state, total_cost) if not state.free_buildings_mode else true
		inspector_panel.update_multi_inspector(ids.size(), total_cost, can_afford)
	else:
		_handle_inspect(0)

func _on_input_demolish_requested(ids: Array[int]) -> void:
	for b_id in ids:
		var building = state.factory.buildings.get(b_id)
		if building:
			BuildingSystem.demolish_building(state, b_id)
			if visuals_map.has(b_id):
				visuals_map[b_id].queue_free()
				visuals_map.erase(b_id)
	selected_building_id = 0
	if is_instance_valid(input_controller):
		input_controller.set_selected_buildings([])
	inspector_panel.visible = false
	_update_ui()
	request_save()

func _on_input_copy_requested(ids: Array[int]) -> void:
	if ids.is_empty():
		return
		
	# Filter out limited buildings (max_count >= 0)
	var valid_ids: Array[int] = []
	for b_id in ids:
		var b_data = state.factory.buildings.get(b_id)
		if b_data:
			var config: BuildingCostData = BuildingSystem.cost_configs.get(b_data.type)
			if config != null and config.max_count >= 0:
				continue # Skip limited buildings
			valid_ids.append(b_id)
			
	if valid_ids.is_empty():
		return
		
	var min_cell = Vector2i(999999, 999999)
	var max_cell = Vector2i(-999999, -999999)
	for b_id in valid_ids:
		var b_data = state.factory.buildings[b_id]
		min_cell.x = mini(min_cell.x, b_data.grid_position.x)
		min_cell.y = mini(min_cell.y, b_data.grid_position.y)
		var end_cell = b_data.grid_position + b_data.size_in_cells
		max_cell.x = maxi(max_cell.x, end_cell.x)
		max_cell.y = maxi(max_cell.y, end_cell.y)
	var bounds_size = max_cell - min_cell
	
	var copied_buildings: Array = []
	var id_to_index: Dictionary = {}
	for i in range(valid_ids.size()):
		var b_id = valid_ids[i]
		id_to_index[b_id] = i
		var b_data = state.factory.buildings[b_id]
		var rel_pos = b_data.grid_position - min_cell
		copied_buildings.append({
			"relative_pos": rel_pos,
			"size": b_data.size_in_cells,
			"type": b_data.type,
			"recipe": b_data.active_recipe.duplicate(true)
		})
		
	var inner_connections: Array = []
	for conn in state.factory.connections:
		if id_to_index.has(conn["from_id"]) and id_to_index.has(conn["to_id"]):
			inner_connections.append({
				"from_index": id_to_index[conn["from_id"]],
				"from_port": conn["from_port"],
				"to_index": id_to_index[conn["to_id"]],
				"to_port": conn["to_port"]
			})
			
	# Calculate total cost
	var total_cost: Dictionary = {}
	var sim_counts: Dictionary = BuildingSystem.get_building_counts(state)
	for b_info in copied_buildings:
		var type = b_info["type"]
		var count = sim_counts.get(type, 0)
		var config: BuildingCostData = BuildingSystem.cost_configs.get(type)
		if config != null:
			var cost = {}
			if count == 0:
				for res in config.base_costs: cost[res] = float(config.base_costs[res])
			else:
				var factor = pow(config.multiplier, count - 1)
				for res in config.first_paid_costs: cost[res] = snappedf(float(config.first_paid_costs[res]) * factor, 0.1)
			for res in cost:
				total_cost[res] = total_cost.get(res, 0.0) + cost[res]
		sim_counts[type] = count + 1
		
	var can_afford = ResourceSystem.can_afford(state, total_cost) if not state.free_buildings_mode else true
	
	if not can_afford and not state.free_buildings_mode:
		inspector_panel.update_multi_inspector(copied_buildings.size(), total_cost, false)
		return
		
	copy_data = {
		"buildings": copied_buildings,
		"connections": inner_connections,
		"bounds_size": bounds_size,
		"total_cost": total_cost
	}
	
	_set_mouse_mode(MouseMode.COPY_BUILD)

func _on_input_copy_placement_confirmed(target_origin_grid: Vector2i) -> void:
	if current_mode != MouseMode.COPY_BUILD or copy_data.is_empty():
		return
		
	var b_list = copy_data.get("buildings", [])
	var total_cost = copy_data.get("total_cost", {})
	
	# Verify area free for all copied buildings
	for b in b_list:
		var rel_pos: Vector2i = b["relative_pos"]
		var b_size: Vector2i = b["size"]
		var cell_pos = target_origin_grid + rel_pos
		if not GridSystem.is_area_free(state.factory, cell_pos, b_size):
			return # Cannot place
			
	var can_afford = ResourceSystem.can_afford(state, total_cost) if not state.free_buildings_mode else true
	if not can_afford:
		return
		
	var new_building_ids: Array[int] = []
	for b in b_list:
		var type = b["type"]
		var cell_pos = target_origin_grid + b["relative_pos"]
		var recipe = b["recipe"].duplicate(true)
		if BuildingSystem.buy_building(state, type):
			var b_data = BuildingSystem.place_building(state, type, cell_pos)
			if b_data and not recipe.is_empty():
				b_data.set_recipe(recipe)
			if type == "portal":
				FlowSystem.sync_portal_inputs(state)
			if b_data:
				_create_building_visual(b_data)
				new_building_ids.append(b_data.id)
			
	for conn in copy_data.get("connections", []):
		var from_idx = conn["from_index"]
		var to_idx = conn["to_index"]
		if from_idx < new_building_ids.size() and to_idx < new_building_ids.size():
			var from_id = new_building_ids[from_idx]
			var to_id = new_building_ids[to_idx]
			FlowSystem.add_connection(state.factory, from_id, to_id, conn["from_port"], conn["to_port"])
			
	_update_ui()
	request_save()
	
	if not Input.is_key_pressed(KEY_SHIFT):
		_set_mouse_mode(MouseMode.INSPECT)

func _on_input_copy_placement_cancelled() -> void:
	_set_mouse_mode(MouseMode.INSPECT)

# --- Template Management ---

func switch_template(target_id: String) -> void:
	if TemplateSystem.switch_template(state, target_id):
		FlowSystem.sync_portal_inputs(state)
		_rebuild_visuals()
		request_save()
		_update_ui()

func create_template(name: String = "") -> void:
	var new_id = TemplateSystem.create_template(state, name)
	request_save()
	_update_ui()

func reset_active_template() -> void:
	TemplateSystem.reset_active_template(state)
	FlowSystem.sync_portal_inputs(state)
	_rebuild_visuals()
	request_save()
	_update_ui()

func delete_active_template() -> void:
	TemplateSystem.delete_active_template(state)
	FlowSystem.sync_portal_inputs(state)
	_rebuild_visuals()
	request_save()
	_update_ui()

func _rebuild_visuals() -> void:
	for visual in visuals_map.values():
		if is_instance_valid(visual):
			visual.queue_free()
	visuals_map.clear()
	selected_building_id = 0
	if inspector_panel != null and inspector_panel.has_method("update_inspector_new"):
		inspector_panel.update_inspector_new(null, null)
		inspector_panel.visible = false
		
	for b_id in state.factory.buildings:
		var b_data = state.factory.buildings[b_id]
		_create_building_visual(b_data)
		
	if is_instance_valid(building_renderer):
		building_renderer.mark_culling_dirty()
		
	connection_renderer.setup(state, visuals_map)
	if is_instance_valid(input_controller):
		input_controller.setup(camera, state, visuals_map, build_preview, building_renderer, connection_renderer)

# --- Offline Catch-up Dialog ---

func _show_offline_catchup_popup(data: Dictionary) -> void:
	if not is_instance_valid(popup_dialog):
		popup_dialog = AcceptDialog.new()
		popup_dialog.title = "Offline Production"
		popup_dialog.dialog_autowrap = false
		hud.add_child(popup_dialog)
		
	var hours = floori(data["elapsed"] / 3600.0)
	var mins = floori((data["elapsed"] % 3600) / 60.0)
	var secs = data["elapsed"] % 60
	
	var time_str = ""
	if hours > 0:
		time_str += "%d h " % hours
	if mins > 0 or hours > 0:
		time_str += "%d m " % mins
	time_str += "%d s" % secs
	
	popup_dialog.dialog_text = "Welcome back!\n\nYour factory was active offline for %s.\n\nSimulated ticks: %d\nCredits earned: $%.1f" % [
		time_str,
		data["simulated_ticks"],
		data["credits_earned"]
	]
	_adjust_popup.call_deferred()

func _adjust_popup() -> void:
	popup_dialog.popup_centered()
	var current_size = popup_dialog.size
	var new_width = current_size.x
	var new_height = current_size.y * 2
	popup_dialog.min_size = Vector2i(new_width, new_height)
	popup_dialog.size = Vector2i(new_width, new_height)
	popup_dialog.popup_centered()

func _on_reset_pressed() -> void:
	# Clear save game
	SaveSystem.delete_save()
	
	# Clear visual instances
	for visual in visuals_map.values():
		if is_instance_valid(visual):
			visual.queue_free()
	visuals_map.clear()
	selected_building_id = 0
	if inspector_panel != null and inspector_panel.has_method("update_inspector_new"):
		inspector_panel.update_inspector_new(null, null)
		inspector_panel.visible = false
	
	# Re-init core
	# Re-init core
	state = GameState.new()
	ResourceSystem.add_resource(state, "credits", 85.0)
	
	ticker = SimulationTicker.new(state)
	ticker.tick_completed.connect(_on_simulation_tick)
	
	connection_renderer.setup(state, visuals_map)
	if is_instance_valid(input_controller):
		input_controller.setup(camera, state, visuals_map, build_preview, building_renderer, connection_renderer)
	if gd_panel != null:
		gd_panel.setup(state, self)
		
	_set_mouse_mode(MouseMode.INSPECT)
	_update_ui()
