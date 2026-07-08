extends Node2D
class_name MainGame

## Main Game Controller. Coordinates simulation, UI, mouse modes, and save management.

enum MouseMode { INSPECT, BUILD, LINK, DEMOLISH }

# Settings
@export var cell_size: int = 64

# Mode State
var current_mode: MouseMode = MouseMode.INSPECT
var selected_build_type: String = ""
var selected_building_id: int = 0
var link_source_id: int = 0

# Core Managers
var network: FactoryNetwork
var economy: EconomyManager
var ticker: SimulationTicker

# Visual maps: building_id -> BuildingVisual
var visuals_map: Dictionary = {}

# Node references
var camera: GameCamera
var grid_renderer: GridRenderer
var connection_renderer: ConnectionRenderer
var buildings_container: Node2D
var build_preview: PanelContainer

# UI References
var credits_label: Label
var stats_label: Label
var tool_buttons: Dictionary = {}
var inspector_panel: PanelContainer
var inspector_details: Label
var popup_dialog: AcceptDialog

# Default recipes for placing buildings
var default_recipes: Dictionary = {
	"miner": {
		"inputs": {},
		"outputs": { "iron_ore": 1.0 },
		"duration": 1.0
	},
	"smelter": {
		"inputs": { "iron_ore": 1.0 },
		"outputs": { "iron_plate": 1.0 },
		"duration": 1.0
	},
	"constructor": {
		"inputs": { "iron_plate": 1.0 },
		"outputs": { "iron_gear": 1.0 },
		"duration": 1.0
	},
	"seller": {
		"inputs": { "iron_gear": 1.0 },
		"outputs": { "credits": 5.0 },
		"duration": 1.0
	}
}

# Auto-save timer
var save_timer: float = 0.0
const AUTO_SAVE_INTERVAL: float = 5.0

func _ready() -> void:
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
	
	# 3. Setup GUI Layout
	_create_hud()
	
	# 4. Load or Init Core Simulation
	_initialize_game()
	
	# Connect to tick signal to update UI
	ticker.tick_completed.connect(_on_simulation_tick)
	
	# Force initial UI update
	_update_ui()

func _initialize_game() -> void:
	var save_data = SaveManager.load_game()
	if not save_data.is_empty():
		var net_dict = save_data["network_dict"]
		var eco_dict = save_data["economy_dict"]
		var saved_time = save_data["timestamp"]
		
		network = FactoryNetwork.from_dict(net_dict)
		economy = EconomyManager.new()
		economy.from_dict(eco_dict)
		ticker = SimulationTicker.new(network, economy)
		
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
		economy = EconomyManager.new()
		ticker = SimulationTicker.new(network, economy)
		
	connection_renderer.setup(network, visuals_map)

func _process(delta: float) -> void:
	# Run simulation ticker ticks
	ticker.process_realtime(delta)
	
	# Process building preview positioning
	if current_mode == MouseMode.BUILD:
		var grid_pos = _get_grid_position_under_mouse()
		build_preview.global_position = Vector2(grid_pos) * cell_size + Vector2(cell_size/2.0 - 55, cell_size/2.0 - 45)
		
		# Color red if blocked, green if empty and affordable
		var style = build_preview.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			if network.grid.has(grid_pos):
				style.border_color = Color(0.9, 0.25, 0.25, 0.8) # Red (blocked)
				style.bg_color = Color(0.9, 0.25, 0.25, 0.15)
			elif not economy.can_afford(selected_build_type):
				style.border_color = Color(0.9, 0.6, 0.1, 0.8) # Orange (unaffordable)
				style.bg_color = Color(0.9, 0.6, 0.1, 0.1)
			else:
				style.border_color = Color(0.2, 0.85, 0.4, 0.8) # Green (OK)
				style.bg_color = Color(0.2, 0.85, 0.4, 0.15)
				
	# Update hovered building state
	var hover_grid_pos = _get_grid_position_under_mouse()
	var hover_building_id = network.grid.get(hover_grid_pos, 0)
	for b_id in visuals_map:
		var visual = visuals_map[b_id]
		if is_instance_valid(visual):
			visual.is_hovered = (b_id == hover_building_id)
			
	# Auto-save
	save_timer += delta
	if save_timer >= AUTO_SAVE_INTERVAL:
		save_timer = 0.0
		SaveManager.save_game(network, economy)
		
	# Redraw for link mode line drawing
	queue_redraw()

func _draw() -> void:
	# Draw temporary connection line if linking
	if current_mode == MouseMode.LINK and link_source_id != 0:
		var source_vis = visuals_map.get(link_source_id)
		if is_instance_valid(source_vis):
			var start_pt = source_vis.global_position
			var end_pt = get_global_mouse_position()
			# Draw dashed or colored linking line
			draw_line(start_pt, end_pt, Color(1.0, 0.9, 0.3, 0.8), 2.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var grid_pos = _get_grid_position_under_mouse()
		var building_id = network.grid.get(grid_pos, 0)
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			match current_mode:
				MouseMode.INSPECT:
					_handle_inspect(building_id)
				MouseMode.BUILD:
					_handle_build(grid_pos)
				MouseMode.LINK:
					_handle_link(building_id)
				MouseMode.DEMOLISH:
					_handle_demolish(building_id)
					
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Cancel build/link modes on RMB
			if current_mode != MouseMode.INSPECT:
				_set_mouse_mode(MouseMode.INSPECT)
				get_viewport().set_input_as_handled()

func _handle_inspect(building_id: int) -> void:
	# Deselect current
	if selected_building_id != 0 and visuals_map.has(selected_building_id):
		visuals_map[selected_building_id].is_selected = false
		
	selected_building_id = building_id
	
	if selected_building_id != 0 and visuals_map.has(selected_building_id):
		visuals_map[selected_building_id].is_selected = true
		_update_inspector()
		inspector_panel.visible = true
	else:
		inspector_panel.visible = false

func _handle_build(grid_pos: Vector2i) -> void:
	if network.grid.has(grid_pos):
		return # Blocked
		
	if not economy.can_afford(selected_build_type):
		return # Cannot afford
		
	# Process purchase
	if economy.buy_building(selected_build_type):
		var recipe = default_recipes[selected_build_type].duplicate(true)
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
	else:
		# We clicked the target building
		if link_source_id != building_id:
			var success = network.add_connection(link_source_id, building_id)
			if success:
				# Highlight success briefly
				_set_mouse_mode(MouseMode.INSPECT)
				_handle_inspect(building_id)
			else:
				# Flash error or just cancel
				visuals_map[link_source_id].is_selected = false
				link_source_id = 0
		else:
			# Cancel if clicking the same building
			visuals_map[link_source_id].is_selected = false
			link_source_id = 0

func _handle_demolish(building_id: int) -> void:
	if building_id == 0:
		return
		
	var building = network.buildings.get(building_id)
	if building:
		# Refund
		economy.refund_building(building.type)
		
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

func _get_grid_position_under_mouse() -> Vector2i:
	var m_pos = get_global_mouse_position()
	return Vector2i(
		floorf(m_pos.x / cell_size),
		floorf(m_pos.y / cell_size)
	)

func _set_mouse_mode(mode: MouseMode, build_type: String = "") -> void:
	# Clean up previous mode state
	if link_source_id != 0 and visuals_map.has(link_source_id):
		visuals_map[link_source_id].is_selected = false
	link_source_id = 0
	
	current_mode = mode
	selected_build_type = build_type
	
	# Show/hide build preview
	build_preview.visible = (current_mode == MouseMode.BUILD)
	
	# Highlight selected button in HUD
	for btn_name in tool_buttons:
		var btn: Button = tool_buttons[btn_name]
		btn.button_pressed = false
		
	var active_btn_name = ""
	match current_mode:
		MouseMode.INSPECT:
			active_btn_name = "inspect"
		MouseMode.LINK:
			active_btn_name = "link"
		MouseMode.DEMOLISH:
			active_btn_name = "demolish"
		MouseMode.BUILD:
			active_btn_name = build_type
			
	if tool_buttons.has(active_btn_name):
		tool_buttons[active_btn_name].button_pressed = true
		
	# Refresh UI
	_update_ui()

func _on_simulation_tick(_ticks: int) -> void:
	_update_ui()
	if selected_building_id != 0:
		_update_inspector()

func _update_ui() -> void:
	# 1. Update global credit amount and delta
	var credits = economy.get_resource("credits")
	
	# Calculate credits income rate (sum of outputs of all seller buildings divided by duration)
	var credits_per_tick = 0.0
	for b in network._buildings_list:
		if b.type == "seller" and not b.active_recipe.is_empty():
			# If it has inputs and produces credits, calculate its production potential per second
			var dur = float(b.active_recipe.get("duration", 1.0))
			var amt = b.active_recipe.get("outputs", {}).get("credits", 0.0)
			credits_per_tick += amt / dur
			
	credits_label.text = "Credits: $%.1f (+%.1f/s)" % [credits, credits_per_tick]
	
	# 2. Update stats
	var miners = economy.building_counts.get("miner", 0)
	var smelters = economy.building_counts.get("smelter", 0)
	var constructors = economy.building_counts.get("constructor", 0)
	var sellers = economy.building_counts.get("seller", 0)
	stats_label.text = "Miners: %d | Smelters: %d | Constructors: %d | Sellers: %d" % [miners, smelters, constructors, sellers]
	
	# 3. Update building cost tags on buttons
	for b_type in ["miner", "smelter", "constructor", "seller"]:
		if tool_buttons.has(b_type):
			var btn: Button = tool_buttons[b_type]
			var cost = economy.get_building_cost(b_type)
			if cost.is_empty():
				btn.text = "%s (Free)" % b_type.capitalize()
			else:
				var cost_val = cost.get("credits", 0.0)
				btn.text = "%s ($%.1f)" % [b_type.capitalize(), cost_val]
				
			# Disable if cannot afford (unless already selected to prevent sudden deselections)
			if not economy.can_afford(b_type) and current_mode != MouseMode.BUILD:
				btn.disabled = true
			else:
				btn.disabled = false

func _update_inspector() -> void:
	var b_data = network.buildings.get(selected_building_id)
	if b_data == null:
		inspector_panel.visible = false
		return
		
	var text = "ID: %d\n" % b_data.id
	text += "Type: %s\n" % b_data.type.capitalize()
	text += "Grid Position: %s\n" % str(b_data.grid_position)
	text += "-------------------------\n"
	
	if not b_data.active_recipe.is_empty():
		text += "Recipe: %s\n" % str(b_data.active_recipe)
		text += "Progress: %.2f / %.1f\n" % [b_data.production_progress, float(b_data.active_recipe.get("duration", 1.0))]
	else:
		text += "Recipe: None\n"
		
	text += "-------------------------\n"
	text += "Inputs:\n"
	for res in b_data.inputs:
		text += "  - %s: %.1f / %.1f\n" % [res, b_data.inputs[res], b_data.input_limits.get(res, 20.0)]
		
	text += "Outputs:\n"
	for res in b_data.outputs:
		text += "  - %s: %.1f / %.1f\n" % [res, b_data.outputs[res], b_data.output_limits.get(res, 20.0)]
		
	inspector_details.text = text

func _create_hud() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)
	
	# Top Menu Panel
	var top_panel = PanelContainer.new()
	top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_panel.custom_minimum_size = Vector2(0, 50)
	
	var top_style = StyleBoxFlat.new()
	top_style.bg_color = Color(0.06, 0.08, 0.1, 0.85)
	top_style.border_width_bottom = 2
	top_style.border_color = Color(0.3, 0.6, 1.0, 0.5)
	top_panel.add_theme_stylebox_override("panel", top_style)
	
	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 20)
	top_panel.add_child(top_hbox)
	
	# Spacing margin
	var margin = Control.new()
	margin.custom_minimum_size = Vector2(10, 0)
	top_hbox.add_child(margin)
	
	credits_label = Label.new()
	credits_label.text = "Credits: $0.0"
	credits_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	credits_label.add_theme_font_size_override("font_size", 16)
	credits_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	credits_label.add_theme_color_override("font_outline_color", Color.BLACK)
	credits_label.add_theme_constant_override("outline_size", 4)
	top_hbox.add_child(credits_label)
	
	stats_label = Label.new()
	stats_label.text = "Miners: 0 | Smelters: 0"
	stats_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	top_hbox.add_child(stats_label)
	
	# Spacer to align buttons right
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer)
	
	# Save/Reset Buttons
	var reset_btn = Button.new()
	reset_btn.text = "Reset Game"
	reset_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reset_btn.pressed.connect(_on_reset_pressed)
	top_hbox.add_child(reset_btn)
	
	var top_margin_r = Control.new()
	top_margin_r.custom_minimum_size = Vector2(10, 0)
	top_hbox.add_child(top_margin_r)
	
	canvas.add_child(top_panel)
	
	# Bottom Toolbar Panel
	var bottom_panel = PanelContainer.new()
	bottom_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.custom_minimum_size = Vector2(0, 60)
	
	var bot_style = StyleBoxFlat.new()
	bot_style.bg_color = Color(0.06, 0.08, 0.1, 0.85)
	bot_style.border_width_top = 2
	bot_style.border_color = Color(0.3, 0.6, 1.0, 0.5)
	bottom_panel.add_theme_stylebox_override("panel", bot_style)
	
	var bot_hbox = HBoxContainer.new()
	bot_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bot_hbox.add_theme_constant_override("separation", 15)
	bottom_panel.add_child(bot_hbox)
	
	# Tool Buttons
	var inspect_btn = Button.new()
	inspect_btn.text = "Inspect"
	inspect_btn.toggle_mode = true
	inspect_btn.button_pressed = true
	inspect_btn.pressed.connect(func(): _set_mouse_mode(MouseMode.INSPECT))
	bot_hbox.add_child(inspect_btn)
	tool_buttons["inspect"] = inspect_btn
	
	# Separator
	var vs1 = VSeparator.new()
	bot_hbox.add_child(vs1)
	
	# Build buttons
	for b_type in ["miner", "smelter", "constructor", "seller"]:
		var btn = Button.new()
		btn.text = b_type.capitalize()
		btn.toggle_mode = true
		btn.pressed.connect(func(): _set_mouse_mode(MouseMode.BUILD, b_type))
		bot_hbox.add_child(btn)
		tool_buttons[b_type] = btn
		
	# Separator
	var vs2 = VSeparator.new()
	bot_hbox.add_child(vs2)
	
	var link_btn = Button.new()
	link_btn.text = "Link Tool"
	link_btn.toggle_mode = true
	link_btn.pressed.connect(func(): _set_mouse_mode(MouseMode.LINK))
	bot_hbox.add_child(link_btn)
	tool_buttons["link"] = link_btn
	
	var demolish_btn = Button.new()
	demolish_btn.text = "Demolish"
	demolish_btn.toggle_mode = true
	demolish_btn.pressed.connect(func(): _set_mouse_mode(MouseMode.DEMOLISH))
	bot_hbox.add_child(demolish_btn)
	tool_buttons["demolish"] = demolish_btn
	
	canvas.add_child(bottom_panel)
	
	# Right Inspector Panel
	inspector_panel = PanelContainer.new()
	inspector_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	inspector_panel.custom_minimum_size = Vector2(250, 0)
	# Add offset from top/bottom HUD panels
	inspector_panel.offset_top = 60
	inspector_panel.offset_bottom = -70
	inspector_panel.visible = false
	
	var insp_style = StyleBoxFlat.new()
	insp_style.bg_color = Color(0.08, 0.1, 0.12, 0.9)
	insp_style.border_width_left = 2
	insp_style.border_color = Color(0.3, 0.6, 1.0, 0.3)
	inspector_panel.add_theme_stylebox_override("panel", insp_style)
	
	var insp_vbox = VBoxContainer.new()
	insp_vbox.add_theme_constant_override("separation", 10)
	inspector_panel.add_child(insp_vbox)
	
	var insp_title = Label.new()
	insp_title.text = "Building Inspector"
	insp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	insp_title.add_theme_font_size_override("font_size", 14)
	insp_title.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
	insp_vbox.add_child(insp_title)
	
	var insp_sep = ColorRect.new()
	insp_sep.custom_minimum_size = Vector2(0, 2)
	insp_sep.color = Color(0.3, 0.6, 1.0, 0.3)
	insp_vbox.add_child(insp_sep)
	
	inspector_details = Label.new()
	inspector_details.text = ""
	inspector_details.add_theme_font_size_override("font_size", 11)
	insp_vbox.add_child(inspector_details)
	
	canvas.add_child(inspector_panel)
	
	# Popup dialog setup for offline catchup
	popup_dialog = AcceptDialog.new()
	popup_dialog.title = "Offline Production"
	popup_dialog.dialog_autowrap = true
	canvas.add_child(popup_dialog)

func _show_offline_catchup_popup(data: Dictionary) -> void:
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
	# Defer popup so engine UI is fully setup
	popup_dialog.call_deferred("popup_centered")

func _on_reset_pressed() -> void:
	# Clear save game
	SaveManager.delete_save()
	
	# Clear visual instances
	for visual in visuals_map.values():
		visual.queue_free()
	visuals_map.clear()
	selected_building_id = 0
	inspector_panel.visible = false
	
	# Re-init core
	network = FactoryNetwork.new()
	economy = EconomyManager.new()
	ticker = SimulationTicker.new(network, economy)
	ticker.tick_completed.connect(_on_simulation_tick)
	
	connection_renderer.setup(network, visuals_map)
	_set_mouse_mode(MouseMode.INSPECT)
	_update_ui()
