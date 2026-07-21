extends Node2D
class_name MainGame

## Main Game Controller. Coordinates simulation, UI, mouse modes, and save management.



enum MouseMode { INSPECT, BUILD, LINK, DEMOLISH }

# Settings
@export var cell_size: int = 32

# Mode State
var current_mode: MouseMode = MouseMode.INSPECT
var selected_build_type: String = ""
var selected_building_id: int = 0
var link_source_id: int = 0


# Core Managers
var network: FactoryNetwork
var resource_manager: ResourceManager
var modifier_manager: ModifierManager
var milestones_manager: MilestonesManager
var artifacts_manager: ArtifactsManager
var building_manager: BuildingManager
var upgrades_manager: UpgradesManager
var ticker: SimulationTicker

# Visual maps: building_id -> BuildingVisual
var visuals_map: Dictionary = {}

# Node references
var camera: GameCamera
var grid_renderer: GridRenderer
var connection_renderer: ConnectionRenderer
var buildings_container: Node2D
var build_preview: PanelContainer

# Input Controller
var input_controller: InputController

# UI References (Instantiated from scenes)
var hud: HUD
var inspector_panel: InspectorPanel
var gd_panel: GDPanel
var popup_dialog: AcceptDialog

# Default recipes for placing buildings, populated dynamically from Recipes database
var default_recipes: Dictionary = {}

# Auto-save timer
var save_timer: float = 0.0
const AUTO_SAVE_INTERVAL: float = 5.0

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
	
	# 4. Load or Init Core Simulation
	_initialize_game()
	
	# 5. Setup GD Debug Panel
	gd_panel = GDPanel.new()
	hud.add_child(gd_panel)
	hud.gd_panel = gd_panel
	gd_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	gd_panel.visible = false
	gd_panel.setup(milestones_manager, upgrades_manager, self)
	
	# Connect to tick signal to update UI
	ticker.tick_completed.connect(_on_simulation_tick)
	
	# Force initial UI update
	_update_ui()

func _initialize_game() -> void:
	var save_data = SaveManager.load_game()
	
	resource_manager = ResourceManager.new()
	modifier_manager = ModifierManager.new()
	milestones_manager = MilestonesManager.new()
	artifacts_manager = ArtifactsManager.new(modifier_manager)
	building_manager = BuildingManager.new(resource_manager, milestones_manager)
	upgrades_manager = UpgradesManager.new(resource_manager, modifier_manager)
	
	if not save_data.is_empty():
		var net_dict = save_data["network_dict"]
		var saved_time = save_data["timestamp"]
		
		network = FactoryNetwork.from_dict(net_dict)
		
		# For old saves, they might come from economy_dict fallback
		# The new load_game() provides them mapped.
		resource_manager.from_dict(save_data.get("resource_manager_dict", {}))
		building_manager.from_dict(save_data.get("building_manager_dict", {}))
		upgrades_manager.from_dict(save_data.get("upgrades_manager_dict", {}))
		artifacts_manager.from_dict(save_data.get("artifacts_manager_dict", {}))
		milestones_manager.from_dict(save_data.get("milestones_manager_dict", {}))
		
		# Migrate old starting credits (50$) to new 85$ for fresh profiles
		var total_buildings = net_dict.get("buildings", []).size()
		if total_buildings == 0 and resource_manager.get_resource("credits") < 85.0:
			resource_manager.add_resource("credits", 85.0 - resource_manager.get_resource("credits"))
			
		ticker = SimulationTicker.new(network, resource_manager, modifier_manager, milestones_manager, artifacts_manager)
		
		# Instantiate visual nodes for all loaded buildings
		for b_id in network.buildings:
			var b_data = network.buildings[b_id]
			_create_building_visual(b_data)
			
		# Handle offline catch-up
		var catchup = ticker.catch_up_offline(saved_time)
		if catchup["simulated_ticks"] > 0:
			_show_offline_catchup_popup(catchup)
	else:
		# Initial state
		network = FactoryNetwork.new()
		ticker = SimulationTicker.new(network, resource_manager, modifier_manager, milestones_manager, artifacts_manager)
		
	connection_renderer.setup(network, visuals_map)
	if is_instance_valid(input_controller):
		input_controller.setup(camera, network, visuals_map, build_preview)

func _process(delta: float) -> void:
	# Run simulation ticker ticks
	ticker.process_realtime(delta)
	
	# Color red if blocked, green if empty and affordable (BUILD preview)
	if current_mode == MouseMode.BUILD and is_instance_valid(input_controller):
		var grid_pos = input_controller._get_build_placement_grid_pos(selected_build_type)
		var b_size = BuildingData.get_default_size(selected_build_type)
		var style = build_preview.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			if not network.is_area_free(grid_pos, b_size):
				style.border_color = Color(0.9, 0.25, 0.25, 0.8) # Red (blocked)
				style.bg_color = Color(0.9, 0.25, 0.25, 0.15)
			elif not building_manager.can_afford(selected_build_type):
				style.border_color = Color(0.9, 0.6, 0.1, 0.8) # Orange (unaffordable)
				style.bg_color = Color(0.9, 0.6, 0.1, 0.1)
			else:
				style.border_color = Color(0.2, 0.85, 0.4, 0.8) # Green (OK)
				style.bg_color = Color(0.2, 0.85, 0.4, 0.15)
			
	# Auto-save
	save_timer += delta
	if save_timer >= AUTO_SAVE_INTERVAL:
		save_timer = 0.0
		SaveManager.save_game(network, resource_manager, building_manager, upgrades_manager, artifacts_manager, milestones_manager)

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

func _handle_build(grid_pos: Vector2i) -> void:
	var b_size = BuildingData.get_default_size(selected_build_type)
	if not network.is_area_free(grid_pos, b_size):
		return # Blocked

		
	if not building_manager.can_afford(selected_build_type):
		return # Cannot afford
		
	# Process purchase
	if building_manager.buy_building(selected_build_type):
		var default_rec = default_recipes.get(selected_build_type, {})
		var recipe = default_rec.duplicate(true) if not default_rec.is_empty() else {}
		var b_data = network.add_building(selected_build_type, grid_pos, recipe)
		_create_building_visual(b_data)
		_update_ui()
		# Remain in build mode for quick placements!


func _handle_link(building_id: int) -> void:
	if building_id == 0:
		return # Must click a building
		
	if link_source_id == 0:
		# Set source
		link_source_id = building_id
		visuals_map[link_source_id].is_selected = true
		if is_instance_valid(input_controller):
			input_controller.link_source_id = link_source_id
	else:
		# We clicked the target building
		if link_source_id != building_id:
			network.add_connection(link_source_id, building_id)
		_set_mouse_mode(MouseMode.INSPECT)

func _handle_demolish(building_id: int) -> void:
	if building_id == 0:
		return
		
	var building = network.buildings.get(building_id)
	if building:
		# Refund
		building_manager.refund_building(building.type)
		
		# Remove from visual system
		if visuals_map.has(building_id):
			visuals_map[building_id].queue_free()
			visuals_map.erase(building_id)
			
		# Remove from model
		network.remove_building(building_id)
		
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
	build_preview.custom_minimum_size = Vector2(110, 90)
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
	
	current_mode = mode
	selected_build_type = build_type
	
	# Show/hide build preview
	build_preview.visible = (current_mode == MouseMode.BUILD)
	
	# Sync state with InputController
	if is_instance_valid(input_controller):
		input_controller.current_mode = current_mode as int
		input_controller.selected_build_type = selected_build_type
		input_controller.link_source_id = link_source_id
		
	# Refresh UI
	_update_ui()

func _on_hud_mode_changed(mode: int, build_type: String) -> void:
	_set_mouse_mode(mode as MouseMode, build_type)

func _on_simulation_tick(_ticks: int) -> void:
	_update_ui()
	if selected_building_id != 0:
		_update_inspector()

func _update_ui() -> void:
	# Calculate credits income rate
	var credits_per_tick = 0.0
	for b in network._buildings_list:
		if b.type == "seller" and not b.active_recipe.is_empty():
			var dur = float(b.active_recipe.get("duration", 1.0))
			var amt = b.active_recipe.get("outputs", {}).get("credits", 0.0)
			credits_per_tick += amt / dur
			
	# Will refactor HUD soon, pass the managers for now
	if hud.has_method("update_hud_new"):
		hud.update_hud_new(resource_manager, building_manager, upgrades_manager, artifacts_manager, milestones_manager, credits_per_tick, current_mode as int, selected_build_type)
	else:
		pass # Ignore old HUD method until refactored

func _update_inspector() -> void:
	var b_data = network.buildings.get(selected_building_id)
	if inspector_panel.has_method("update_inspector_new"):
		inspector_panel.update_inspector_new(b_data, building_manager)
	else:
		pass # Ignore old inspector panel method until refactored


func _on_recipe_selected(idx: int) -> void:
	var b_data = network.buildings.get(selected_building_id)
	if b_data == null:
		return
	var possible_recipes = Recipes.DATA.get(b_data.type, [])
	if idx >= 0 and idx < possible_recipes.size():
		var new_recipe = possible_recipes[idx].duplicate(true)
		b_data.set_recipe(new_recipe)
		network.rebuild_caches()
		_update_inspector()
		SaveManager.save_game(network, resource_manager, building_manager, upgrades_manager, artifacts_manager, milestones_manager)

# --- Input Controller Handlers ---

func _on_input_building_clicked(building_id: int) -> void:
	if current_mode == MouseMode.LINK:
		_handle_link(building_id)
	elif current_mode == MouseMode.DEMOLISH:
		_handle_demolish(building_id)
	else:
		_handle_inspect(building_id)

func _on_input_building_right_clicked(building_id: int) -> void:
	_set_mouse_mode(MouseMode.LINK)
	link_source_id = building_id
	visuals_map[link_source_id].is_selected = true
	if is_instance_valid(input_controller):
		input_controller.link_source_id = link_source_id

func _on_input_empty_space_clicked(grid_pos: Vector2i) -> void:
	if current_mode == MouseMode.BUILD:
		_handle_build(grid_pos)
	else:
		_handle_inspect(0)

func _on_input_building_move_completed() -> void:
	SaveManager.save_game(network, resource_manager, building_manager, upgrades_manager, artifacts_manager, milestones_manager)

func _on_input_link_mode_cancelled() -> void:
	_set_mouse_mode(MouseMode.INSPECT)

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
	SaveManager.delete_save()
	
	# Clear visual instances
	for visual in visuals_map.values():
		visual.queue_free()
	visuals_map.clear()
	selected_building_id = 0
	if inspector_panel.has_method("update_inspector_new"):
		inspector_panel.update_inspector_new(null, null)
	
	# Re-init core
	network = FactoryNetwork.new()
	resource_manager = ResourceManager.new()
	modifier_manager = ModifierManager.new()
	milestones_manager = MilestonesManager.new()
	artifacts_manager = ArtifactsManager.new(modifier_manager)
	building_manager = BuildingManager.new(resource_manager, milestones_manager)
	upgrades_manager = UpgradesManager.new(resource_manager, modifier_manager)
	ticker = SimulationTicker.new(network, resource_manager, modifier_manager, milestones_manager, artifacts_manager)
	ticker.tick_completed.connect(_on_simulation_tick)
	
	connection_renderer.setup(network, visuals_map)
	if is_instance_valid(input_controller):
		input_controller.setup(camera, network, visuals_map, build_preview)
		
	_set_mouse_mode(MouseMode.INSPECT)
	_update_ui()
