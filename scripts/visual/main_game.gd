extends Node2D
class_name MainGame

const Recipes = preload("res://scripts/core/recipes.gd")

## Main Game Controller. Coordinates simulation, UI, mouse modes, and save management.

enum MouseMode { INSPECT, BUILD, LINK, DEMOLISH }

# Settings
@export var cell_size: int = 64

# Mode State
var current_mode: MouseMode = MouseMode.INSPECT
var selected_build_type: String = ""
var selected_building_id: int = 0
var link_source_id: int = 0

# Building Drag & Panning State
var _is_dragging_building: bool = false
var _dragged_building_id: int = 0
var _drag_building_start_grid: Vector2i
var _lmb_press_pos: Vector2
var _has_dragged: bool = false

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

# Card UI references and Drag state
var tool_cost_labels: Dictionary = {}
var _scroll_container: ScrollContainer
var _is_scrolling_drag: bool = false
var _scroll_drag_start_pos: Vector2
var _scroll_drag_start_val: int
var _scroll_has_dragged: bool = false

const BUILDING_DESCRIPTIONS: Dictionary = {
	"miner_iron": "➔ Iron Ore",
	"miner_coal": "➔ Coal",
	"miner_crystal": "➔ Mana Crystal",
	"crusher": "Ore ➔ Dust",
	"smelter": "Ore ➔ Plate/Ingot",
	"constructor": "Plate ➔ Gear",
	"alchemy_lab": "Dust ➔ Essence",
	"artifact_altar": "Ingot ➔ Amulet",
	"seller": "Goods ➔ Credits"
}

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
		# Migrate old starting credits (50$) to new 85$ for fresh profiles
		var total_buildings = net_dict.get("buildings", []).size()
		if total_buildings == 0 and economy.get_resource("credits") < 85.0:
			economy.resources["credits"] = 85.0
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
	var hover_building_id = _get_building_id_under_mouse()
	for b_id in visuals_map:
		var visual = visuals_map[b_id]
		if is_instance_valid(visual):
			if _is_dragging_building and b_id == _dragged_building_id:
				visual.is_hovered = false
			else:
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
	if event is InputEventMouseButton:
		var building_id = _get_building_id_under_mouse()
		var grid_pos = _get_grid_position_under_mouse()
		if building_id != 0:
			grid_pos = network.buildings[building_id].grid_position
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start left click actions
				_lmb_press_pos = get_global_mouse_position()
				_has_dragged = false
				
				# Drag building: only if we clicked a building and we are in Inspect or Build mode
				if building_id != 0 and (current_mode == MouseMode.INSPECT or current_mode == MouseMode.BUILD):
					_is_dragging_building = true
					_dragged_building_id = building_id
					_drag_building_start_grid = grid_pos
				else:
					# Otherwise, pan camera using LMB
					camera.is_panning = true
			else:
				# Left mouse button released
				if camera.is_panning:
					camera.is_panning = false
					# If we clicked empty space (not dragged camera), trigger actions
					if not _has_dragged:
						if current_mode == MouseMode.LINK:
							if building_id != 0:
								_handle_link(building_id)
							else:
								# Cancel linking on empty space click
								_set_mouse_mode(MouseMode.INSPECT)
						elif current_mode == MouseMode.BUILD:
							if building_id == 0:
								_handle_build(grid_pos)
							else:
								# Clicked a building in build mode -> inspect it
								_handle_inspect(building_id)
						elif current_mode == MouseMode.DEMOLISH:
							_handle_demolish(building_id)
						else:
							# Inspect empty space to deselect
							_handle_inspect(0)
							
				elif _is_dragging_building:
					if _has_dragged:
						# Drag completed - building is already at its final grid position!
						# Just force save the state.
						SaveManager.save_game(network, economy)
					else:
						# It was a short click, not a drag: inspect the clicked building
						if current_mode == MouseMode.DEMOLISH:
							_handle_demolish(_dragged_building_id)
						else:
							_handle_inspect(_dragged_building_id)
							
					_is_dragging_building = false
					_dragged_building_id = 0
					
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				# RMB on building -> start linking
				if building_id != 0:
					_set_mouse_mode(MouseMode.LINK)
					link_source_id = building_id
					visuals_map[link_source_id].is_selected = true
				else:
					# RMB on empty space -> cancel current non-inspect mode
					if current_mode != MouseMode.INSPECT:
						_set_mouse_mode(MouseMode.INSPECT)
						get_viewport().set_input_as_handled()
						
	elif event is InputEventMouseMotion:
		# Drag threshold checks
		if _is_dragging_building:
			if get_global_mouse_position().distance_to(_lmb_press_pos) > 8:
				_has_dragged = true
				
			var hover_grid_pos = _get_grid_position_under_mouse()
			var b_data = network.buildings.get(_dragged_building_id)
			if b_data and hover_grid_pos != b_data.grid_position:
				# Only move if the target grid position is empty
				if not network.grid.has(hover_grid_pos):
					# Remove from old grid pos
					network.grid.erase(b_data.grid_position)
					# Add to new grid pos
					network.grid[hover_grid_pos] = _dragged_building_id
					# Update building data pos
					b_data.grid_position = hover_grid_pos
					
					network.rebuild_caches()
					
					# Snap visual position to the grid cell center
					var visual = visuals_map.get(_dragged_building_id)
					if is_instance_valid(visual):
						visual.position = Vector2(hover_grid_pos) * cell_size + Vector2(cell_size / 2.0, cell_size / 2.0)
					
		elif camera.is_panning:
			if get_global_mouse_position().distance_to(_lmb_press_pos) > 8:
				_has_dragged = true

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
				# Link created successfully - return to inspect mode without selecting the target
				_set_mouse_mode(MouseMode.INSPECT)
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

func _get_building_id_under_mouse() -> int:
	var m_pos = get_global_mouse_position()
	for b_id in visuals_map:
		var visual = visuals_map[b_id]
		if is_instance_valid(visual):
			var rect = Rect2(visual.global_position - Vector2(55, 45), Vector2(110, 90))
			if rect.has_point(m_pos):
				return b_id
	return 0

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
	var miners = economy.building_counts.get("miner", 0) + economy.building_counts.get("miner_iron", 0) + economy.building_counts.get("miner_coal", 0) + economy.building_counts.get("miner_crystal", 0)
	var smelters = economy.building_counts.get("smelter", 0)
	var constructors = economy.building_counts.get("constructor", 0)
	var sellers = economy.building_counts.get("seller", 0)
	var crushers = economy.building_counts.get("crusher", 0)
	var labs = economy.building_counts.get("alchemy_lab", 0)
	var altars = economy.building_counts.get("artifact_altar", 0)
	stats_label.text = "Miners: %d | Crushers: %d | Smelters: %d | Constructors: %d | Labs: %d | Altars: %d | Sellers: %d" % [
		miners, crushers, smelters, constructors, labs, altars, sellers
	]
	
	# 3. Update building cost tags on buttons
	for b_type in ["miner_iron", "miner_coal", "miner_crystal", "crusher", "smelter", "constructor", "alchemy_lab", "artifact_altar", "seller"]:
		if tool_buttons.has(b_type):
			var btn: Button = tool_buttons[b_type]
			var cost = economy.get_building_cost(b_type)
			var price_lbl = tool_cost_labels.get(b_type)
			if price_lbl:
				if cost.is_empty():
					price_lbl.text = "Free"
				else:
					var cost_val = cost.get("credits", 0.0)
					price_lbl.text = "$%.1f" % cost_val
				
			# Disable if cannot afford (unless already selected to prevent sudden deselections)
			var is_selected_type = (current_mode == MouseMode.BUILD and selected_build_type == b_type)
			if not economy.can_afford(b_type) and not is_selected_type:
				btn.disabled = true
				if price_lbl:
					price_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
			else:
				btn.disabled = false
				if price_lbl:
					price_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))

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
		text += "Recipe: %s\n" % b_data.active_recipe.get("name", b_data.active_recipe.get("id", "Unknown"))
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

	# Update Recipe OptionButton
	var recipe_container = inspector_panel.find_child("RecipeSelectorContainer", true, false)
	var recipe_button: OptionButton = inspector_panel.find_child("RecipeOptionButton", true, false)
	
	if recipe_container and recipe_button:
		var possible_recipes = Recipes.DATA.get(b_data.type, [])
		if possible_recipes.size() > 1:
			recipe_container.visible = true
			recipe_button.clear()
			
			var active_recipe_id = b_data.active_recipe.get("id", "")
			var select_idx = 0
			for i in range(possible_recipes.size()):
				var recipe = possible_recipes[i]
				recipe_button.add_item(recipe.get("name", recipe.get("id", "Unknown")))
				if recipe.get("id", "") == active_recipe_id:
					select_idx = i
					
			recipe_button.selected = select_idx
			
			if recipe_button.item_selected.is_connected(_on_recipe_selected):
				recipe_button.item_selected.disconnect(_on_recipe_selected)
			recipe_button.item_selected.connect(_on_recipe_selected)
		else:
			recipe_container.visible = false

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
		SaveManager.save_game(network, economy)

func _create_hud() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)
	
	# Top Menu Panel
	var top_panel = PanelContainer.new()
	canvas.add_child(top_panel)
	top_panel.custom_minimum_size = Vector2(0, 50)
	top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_bottom = 50
	
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
	
	# Bottom Toolbar Panel
	var bottom_panel = PanelContainer.new()
	canvas.add_child(bottom_panel)
	bottom_panel.custom_minimum_size = Vector2(0, 150)
	bottom_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.offset_top = -150
	bottom_panel.offset_bottom = 0
	
	var bot_style = StyleBoxFlat.new()
	bot_style.bg_color = Color(0.06, 0.08, 0.1, 0.85)
	bot_style.border_width_top = 2
	bot_style.border_color = Color(0.3, 0.6, 1.0, 0.5)
	bottom_panel.add_theme_stylebox_override("panel", bot_style)
	
	var bot_margin = MarginContainer.new()
	bot_margin.add_theme_constant_override("margin_left", 10)
	bot_margin.add_theme_constant_override("margin_right", 10)
	bot_margin.add_theme_constant_override("margin_top", 10)
	bot_margin.add_theme_constant_override("margin_bottom", 10)
	bottom_panel.add_child(bot_margin)
	
	_scroll_container = ScrollContainer.new()
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll_container.mouse_filter = Control.MOUSE_FILTER_PASS
	bot_margin.add_child(_scroll_container)
	_scroll_container.gui_input.connect(func(event): _on_button_gui_input("", event))
	
	var bot_hbox = HBoxContainer.new()
	bot_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	bot_hbox.add_theme_constant_override("separation", 12)
	_scroll_container.add_child(bot_hbox)
	
	# Build buttons (cards)
	var card_types = ["miner_iron", "miner_coal", "miner_crystal", "crusher", "smelter", "constructor", "alchemy_lab", "artifact_altar", "seller"]
	for b_type in card_types:
		_create_building_card(bot_hbox, b_type)
		
	# Separator
	var vs = VSeparator.new()
	vs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot_hbox.add_child(vs)
	
	# Demolish button (card)
	_create_building_card(bot_hbox, "demolish")
	
	# Right Inspector Panel
	inspector_panel = PanelContainer.new()
	canvas.add_child(inspector_panel)
	inspector_panel.custom_minimum_size = Vector2(250, 0)
	inspector_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	inspector_panel.offset_left = -250
	inspector_panel.offset_right = 0
	# Add offset from top/bottom HUD panels
	inspector_panel.offset_top = 60
	inspector_panel.offset_bottom = -160
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
	
	# Recipe Selector UI container
	var recipe_container = HBoxContainer.new()
	recipe_container.name = "RecipeSelectorContainer"
	recipe_container.visible = false
	insp_vbox.add_child(recipe_container)
	
	var recipe_lbl = Label.new()
	recipe_lbl.text = "Recipe:"
	recipe_lbl.add_theme_font_size_override("font_size", 11)
	recipe_container.add_child(recipe_lbl)
	
	var recipe_opt = OptionButton.new()
	recipe_opt.name = "RecipeOptionButton"
	recipe_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_opt.add_theme_font_size_override("font_size", 10)
	recipe_container.add_child(recipe_opt)
	
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

func _get_accent_color(type: String) -> Color:
	match type:
		"miner":
			return Color(0.9, 0.45, 0.1) # Amber / Orange
		"miner_iron":
			return Color(0.8, 0.5, 0.3) # Iron brown
		"miner_coal":
			return Color(0.3, 0.3, 0.35) # Dark gray
		"miner_crystal":
			return Color(0.7, 0.4, 0.9) # Magical purple
		"crusher":
			return Color(0.5, 0.5, 0.5) # Steel gray
		"smelter":
			return Color(0.95, 0.25, 0.25) # Hot Red
		"constructor":
			return Color(0.2, 0.7, 0.9) # Cyan
		"alchemy_lab":
			return Color(0.1, 0.8, 0.8) # Teal alchemical glow
		"artifact_altar":
			return Color(0.9, 0.8, 0.2) # Golden magic yellow
		"seller":
			return Color(0.2, 0.85, 0.4) # Emerald Green
		"demolish":
			return Color(0.95, 0.25, 0.25) # Red for Demolish
		_:
			return Color(0.7, 0.7, 0.7)

func _create_card_style(accent_color: Color, state: String) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	
	match state:
		"normal":
			style.bg_color = Color(0.08, 0.1, 0.12, 0.95)
			style.border_color = accent_color.darkened(0.3)
			style.shadow_color = Color(0, 0, 0, 0.3)
			style.shadow_size = 4
		"hover":
			style.bg_color = Color(0.12, 0.15, 0.18, 0.95)
			style.border_color = accent_color.lightened(0.1)
			style.shadow_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.15)
			style.shadow_size = 6
		"pressed":
			style.bg_color = Color(0.15, 0.2, 0.25, 0.95)
			style.border_color = Color(1.0, 0.9, 0.3) # Gold selection
			style.shadow_color = Color(1.0, 0.9, 0.3, 0.25)
			style.shadow_size = 8
		"disabled":
			style.bg_color = Color(0.04, 0.05, 0.06, 0.8)
			style.border_color = accent_color.darkened(0.7)
			style.shadow_size = 0
	return style

func _create_building_card(parent_container: Control, b_type: String) -> void:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(120, 110)
	btn.toggle_mode = true
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var color = _get_accent_color(b_type)
	btn.add_theme_stylebox_override("normal", _create_card_style(color, "normal"))
	btn.add_theme_stylebox_override("hover", _create_card_style(color, "hover"))
	btn.add_theme_stylebox_override("pressed", _create_card_style(color, "pressed"))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("disabled", _create_card_style(color, "disabled"))
	
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn.add_child(vbox)
	
	var title_lbl = Label.new()
	if b_type == "demolish":
		title_lbl.text = "Demolish"
	elif b_type.begins_with("miner_"):
		title_lbl.text = b_type.replace("miner_", "").capitalize() + " Miner"
	else:
		title_lbl.text = b_type.capitalize()
		
	title_lbl.add_theme_font_size_override("font_size", 11)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_lbl)
	
	var div = ColorRect.new()
	div.custom_minimum_size = Vector2(0, 2)
	div.color = color
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(div)
	
	var desc_lbl = Label.new()
	if b_type == "demolish":
		desc_lbl.text = "Refund 100%"
	else:
		desc_lbl.text = BUILDING_DESCRIPTIONS.get(b_type, "")
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_lbl)
	
	var price_lbl = Label.new()
	price_lbl.name = "PriceLabel"
	price_lbl.add_theme_font_size_override("font_size", 11)
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if b_type == "demolish":
		price_lbl.text = "Action"
		price_lbl.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3))
	else:
		price_lbl.text = "$0.0"
		price_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(price_lbl)
	
	btn.gui_input.connect(func(event): _on_button_gui_input(b_type, event))
	
	parent_container.add_child(btn)
	tool_buttons[b_type] = btn
	if b_type != "demolish":
		tool_cost_labels[b_type] = price_lbl

func _on_button_gui_input(b_type: String, event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_scrolling_drag = true
				_scroll_drag_start_pos = event.global_position
				_scroll_drag_start_val = _scroll_container.scroll_horizontal
				_scroll_has_dragged = false
			else:
				_is_scrolling_drag = false
				if not _scroll_has_dragged and not b_type.is_empty():
					_on_building_button_pressed(b_type)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_container.scroll_horizontal -= 40
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_container.scroll_horizontal += 40
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _is_scrolling_drag:
		var diff = event.global_position.x - _scroll_drag_start_pos.x
		if abs(diff) > 8:
			_scroll_has_dragged = true
		_scroll_container.scroll_horizontal = _scroll_drag_start_val - int(diff)
		get_viewport().set_input_as_handled()

func _on_building_button_pressed(b_type: String) -> void:
	if b_type == "demolish":
		_set_mouse_mode(MouseMode.DEMOLISH)
	else:
		_set_mouse_mode(MouseMode.BUILD, b_type)
