extends Node2D
class_name BuildingVisual

## Visual representation of a building on the grid, syncing with BuildingData.

var data: BuildingData
var cell_size: int = 64
var is_selected: bool = false
var is_hovered: bool = false
var is_invalid_drag: bool = false

# UI references
var panel: PanelContainer
var title_label: Label
var progress_bar: ProgressBar
var inputs_container: VBoxContainer
var outputs_container: VBoxContainer

# Styling Colors based on building type
var accent_color: Color = Color.WHITE

var port_flash_timers: Array[float] = [0.0, 0.0, 0.0]

func trigger_output_pulse(port_idx: int) -> void:
	while port_flash_timers.size() <= port_idx:
		port_flash_timers.append(0.0)
	port_flash_timers[port_idx] = 0.35
	request_overlay_redraw()

func setup(p_data: BuildingData, p_cell_size: int) -> void:
	data = p_data
	cell_size = p_cell_size
	
	# Determine colors based on type
	match data.type:
		"portal":
			accent_color = Color(1.0, 0.65, 0.2) # Portal orange magic
		"miner", "miner_iron", "miner_coal", "miner_crystal":
			accent_color = Color(0.9, 0.45, 0.1) # Amber / Mining Orange
		"smelter":
			accent_color = Color(0.95, 0.25, 0.25) # Hot Red
		"converter", "constructor", "crusher":
			accent_color = Color(0.2, 0.8, 0.5) # Emerald Mint
		"assembler":
			accent_color = Color(0.3, 0.5, 0.95) # Deep Royal Blue
		"extractor":
			accent_color = Color(0.85, 0.35, 0.85) # Aether Magenta
		"infuser", "alchemy_lab":
			accent_color = Color(0.9, 0.5, 0.9) # Purple Infusion
		"artifact_altar":
			accent_color = Color(0.9, 0.8, 0.2) # Golden magic yellow
		"seller":
			accent_color = Color(0.2, 0.85, 0.4) # Emerald Green
		"splitter_2", "splitter_3":
			accent_color = Color(0.9, 0.9, 0.3) # Logic Bright Yellow
		_:
			accent_color = Color(0.7, 0.7, 0.7)
			
	# Set visual position (centered on building footprint)
	var size_px = Vector2(data.size_in_cells * cell_size)
	position = Vector2(data.grid_position) * cell_size + size_px / 2.0
	
	_create_ui()
	_update_ui()

func _draw() -> void:
	pass # Drawing is handled by Overlay Control on top of panel background

func _to_overlay_local(overlay: Control, global_pos: Vector2) -> Vector2:
	return overlay.get_global_transform().affine_inverse() * global_pos

func _on_overlay_draw() -> void:
	if data == null or not is_instance_valid(panel):
		return
		
	var overlay = panel.get_node_or_null("Overlay") as Control
	if overlay == null:
		return
		
	# Minimalist visual representation for splitters (internal lines + flashing + next target highlight)
	if data.type.begins_with("splitter"):
		var in_pt = _to_overlay_local(overlay, get_port_global_position(false, 0))
		var out_count = BuildingData.get_output_ports_count(data.type)
		var next_target_idx = (data.last_outgoing_conn_index % max(1, out_count)) if data != null else 0
		
		for i in range(out_count):
			var out_pt = _to_overlay_local(overlay, get_port_global_position(true, i))
			var is_flashing = (i < port_flash_timers.size() and port_flash_timers[i] > 0.0)
			var is_next = (i == next_target_idx)
			
			if is_flashing:
				var alpha = minf(1.0, port_flash_timers[i] / 0.15)
				# Wide outer glow
				overlay.draw_line(in_pt, out_pt, Color(1.0, 0.85, 0.2, alpha * 0.7), 6.0)
				# Core bright line
				overlay.draw_line(in_pt, out_pt, Color(1.0, 1.0, 0.7, alpha), 3.0)
				overlay.draw_circle(out_pt, 5.5, Color(1.0, 0.9, 0.3, 1.0))
				overlay.draw_arc(out_pt, 5.5, 0, TAU, 16, Color.BLACK, 1.5)
			elif is_next:
				# Highlighted next target line (width 3.0, alpha 0.4)
				overlay.draw_line(in_pt, out_pt, Color(0.9, 0.8, 0.35, 0.4), 3.0)
				overlay.draw_circle(out_pt, 5.0, Color(0.9, 0.8, 0.35, 0.65))
				overlay.draw_arc(out_pt, 5.0, 0, TAU, 16, Color.BLACK, 1.5)
			else:
				# Neutral grey inactive line
				overlay.draw_line(in_pt, out_pt, Color(0.3, 0.35, 0.4, 0.4), 1.5)
				overlay.draw_circle(out_pt, 4.5, Color(0.6, 0.65, 0.7, 0.6))
				overlay.draw_arc(out_pt, 4.5, 0, TAU, 16, Color.BLACK, 1.2)
			
		overlay.draw_circle(in_pt, 5.0, Color(0.3, 0.7, 1.0, 0.9)) # Blue input dot
		overlay.draw_arc(in_pt, 5.0, 0, TAU, 16, Color.BLACK, 1.5)
		return

	var recipe_ctx = {"inputs": data.inputs, "outputs": data.outputs}
	var out_count = BuildingData.get_output_ports_count(data.type, recipe_ctx)
	for i in range(out_count):
		var pt = _to_overlay_local(overlay, get_port_global_position(true, i))
		overlay.draw_circle(pt, 5.0, Color(1.0, 0.85, 0.2, 0.9)) # Orange/Yellow output dot
		overlay.draw_arc(pt, 5.0, 0, TAU, 16, Color.BLACK, 1.5)
		
	var in_count = BuildingData.get_input_ports_count(data.type, recipe_ctx)
	for i in range(in_count):
		var pt = _to_overlay_local(overlay, get_port_global_position(false, i))
		overlay.draw_circle(pt, 5.0, Color(0.3, 0.7, 1.0, 0.9)) # Blue input dot
		overlay.draw_arc(pt, 5.0, 0, TAU, 16, Color.BLACK, 1.5)

func request_overlay_redraw() -> void:
	queue_redraw()
	if is_instance_valid(panel) and panel.has_node("Overlay"):
		(panel.get_node("Overlay") as Control).queue_redraw()

func _create_ui() -> void:
	var size_px = Vector2(data.size_in_cells * cell_size)
	# Create PanelContainer for the building block
	panel = PanelContainer.new()
	panel.custom_minimum_size = size_px
	panel.position = -size_px / 2.0 # Centered
	
	# Create Custom StyleBox for the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.12, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = accent_color.darkened(0.3)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 4
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 5 # 2px border + 3px bottom padding
	panel.add_theme_stylebox_override("panel", style)
	
	# Mouse filter to let MainGame handle selection clicks
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Inside panel: VBoxContainer
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	
	# 1. Title (Type name)
	title_label = Label.new()
	title_label.text = data.type.capitalize()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.add_theme_color_override("font_color", accent_color)
	# Bold outline
	title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	title_label.add_theme_constant_override("outline_size", 3)
	vbox.add_child(title_label)
	
	# 2. Production Progress Bar
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 6)
	progress_bar.show_percentage = false
	
	var pb_bg = StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.04, 0.05, 0.06, 1.0)
	pb_bg.corner_radius_top_left = 3
	pb_bg.corner_radius_top_right = 3
	pb_bg.corner_radius_bottom_left = 3
	pb_bg.corner_radius_bottom_right = 3
	
	var pb_fg = StyleBoxFlat.new()
	pb_fg.bg_color = accent_color
	pb_fg.corner_radius_top_left = 3
	pb_fg.corner_radius_top_right = 3
	pb_fg.corner_radius_bottom_left = 3
	pb_fg.corner_radius_bottom_right = 3
	
	progress_bar.add_theme_stylebox_override("background", pb_bg)
	progress_bar.add_theme_stylebox_override("fill", pb_fg)
	vbox.add_child(progress_bar)
	
	# Separator
	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(0.2, 0.25, 0.3, 0.3)
	vbox.add_child(sep)
	
	# Top: Inputs list (Sequential vertical)
	inputs_container = VBoxContainer.new()
	inputs_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inputs_container.add_theme_constant_override("separation", 1)
	vbox.add_child(inputs_container)
	
	# Bottom: Outputs list (Sequential vertical)
	outputs_container = VBoxContainer.new()
	outputs_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outputs_container.add_theme_constant_override("separation", 1)
	vbox.add_child(outputs_container)
	
	# Minimalist mode for splitters: hide header and resource lists
	if data.type.begins_with("splitter"):
		title_label.visible = false
		progress_bar.visible = false
		sep.visible = false
		inputs_container.visible = false
		outputs_container.visible = false
	
	# Create Overlay Control inside panel to draw internal lines & ports on top of panel background
	var overlay = Control.new()
	overlay.name = "Overlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(overlay)
	overlay.draw.connect(_on_overlay_draw)

	add_child(panel)
	_set_mouse_ignore(panel)

func _set_mouse_ignore(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_ignore(child)

func _process(delta: float) -> void:
	if data == null:
		return
	_update_ui()
	var needs_redraw = false
	for i in range(port_flash_timers.size()):
		if port_flash_timers[i] > 0.0:
			port_flash_timers[i] = maxf(0.0, port_flash_timers[i] - delta)
			needs_redraw = true
	if needs_redraw:
		request_overlay_redraw()

func _update_ui() -> void:
	# Update panel dimensions if size_in_cells changed
	var size_px = Vector2(data.size_in_cells * cell_size)
	if panel.custom_minimum_size != size_px:
		panel.custom_minimum_size = size_px
		panel.position = -size_px / 2.0
		position = Vector2(data.grid_position) * cell_size + size_px / 2.0

	# Update progress bar
	if data.type.begins_with("splitter") or data.type == "portal" or data.active_recipe.is_empty():
		progress_bar.visible = false
	else:
		progress_bar.visible = true
		var duration = float(data.active_recipe.get("duration", 1.0))
		progress_bar.max_value = duration
		progress_bar.value = data.production_progress
		
	# Update input and output buffer texts
	_update_resource_list(inputs_container, data.inputs, data.input_limits, true)
	_update_resource_list(outputs_container, data.outputs, data.output_limits, false)
	
	# Update glow/borders based on selection, hover, and invalid drag
	var style = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		if is_invalid_drag:
			style.border_color = Color(0.9, 0.25, 0.25) # Bright red for collision during drag
			style.border_width_left = 3
			style.border_width_right = 3
			style.border_width_top = 3
			style.border_width_bottom = 3
			style.shadow_size = 8
			style.shadow_color = Color(0.9, 0.25, 0.25, 0.4)
		elif is_selected:
			style.border_color = Color(1.0, 0.9, 0.3) # Golden border for selection
			style.border_width_left = 3
			style.border_width_right = 3
			style.border_width_top = 3
			style.border_width_bottom = 3
			style.shadow_size = 8
			style.shadow_color = Color(1.0, 0.9, 0.3, 0.25)
		elif is_hovered:
			style.border_color = accent_color.lightened(0.2)
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
			style.shadow_size = 6
			style.shadow_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.2)
		else:
			style.border_color = accent_color.darkened(0.3)
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
			style.shadow_size = 4
			style.shadow_color = Color(0, 0, 0, 0.3)

func _update_resource_list(container: VBoxContainer, resources: Dictionary, limits: Dictionary, is_input: bool) -> void:
	var display_res: Dictionary = {}
	for res in resources:
		if not res.begins_with("_"):
			display_res[res] = resources[res]

	# Rebuild children if count or resource keys mismatch
	var needs_rebuild = false
	if container.get_child_count() != display_res.size():
		needs_rebuild = true
	else:
		for res in display_res:
			if not container.has_node(res):
				needs_rebuild = true
				break
				
	if needs_rebuild:
		for child in container.get_children():
			child.queue_free()
			container.remove_child(child)
		
		for res in display_res:
			var lbl = Label.new()
			lbl.name = res
			lbl.add_theme_font_size_override("font_size", 9)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if is_input else HORIZONTAL_ALIGNMENT_RIGHT
			lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			lbl.clip_text = true
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			container.add_child(lbl)
			
	# Update text values
	for child in container.get_children():
		var res_name = child.name
		if display_res.has(res_name):
			var val = int(round(display_res[res_name]))
			var short_name = res_name.replace("iron_", "").replace("_", " ").capitalize()
			child.text = "%s: %d" % [short_name, val]
			if is_input:
				child.add_theme_color_override("font_color", Color(0.8, 0.7, 0.7))
			else:
				child.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))

## Finds input port index corresponding to an incoming resource.
func get_input_port_for_resource(res_name: String) -> int:
	if data == null:
		return 0
	if inputs_container != null:
		for i in range(inputs_container.get_child_count()):
			if inputs_container.get_child(i).name == res_name:
				return i
	return 0

## Helper function to calculate exact global position of input/output port anchor.
func get_port_global_position(is_output: bool, port_idx: int) -> Vector2:
	if data == null:
		return global_position
		
	var half_width = data.size_in_cells.x * cell_size / 2.0
	var half_height = data.size_in_cells.y * cell_size / 2.0
	
	if data.type.begins_with("splitter"):
		if not is_output:
			return Vector2(global_position.x - half_width, global_position.y)
		else:
			var total_ports = BuildingData.get_output_ports_count(data.type)
			port_idx = clamp(port_idx, 0, total_ports - 1)
			if total_ports <= 2:
				var offset_y = -half_height * 0.45 if port_idx == 0 else half_height * 0.45
				return Vector2(global_position.x + half_width, global_position.y + offset_y)
			else:
				var offsets = [-half_height * 0.55, 0.0, half_height * 0.55]
				return Vector2(global_position.x + half_width, global_position.y + offsets[port_idx])
	
	var recipe_ctx = {"inputs": data.inputs, "outputs": data.outputs}
	var in_count = BuildingData.get_input_ports_count(data.type, recipe_ctx)
	var out_count = BuildingData.get_output_ports_count(data.type, recipe_ctx)
	var total_ports = out_count if is_output else in_count
	if total_ports <= 0:
		return global_position
		
	port_idx = clamp(port_idx, 0, total_ports - 1)
	var side_x = half_width if is_output else -half_width
	var target_container = outputs_container if is_output else inputs_container
	
	# Align port vertically with corresponding resource label if present
	if is_instance_valid(target_container) and port_idx < target_container.get_child_count():
		var child = target_container.get_child(port_idx) as Control
		if is_instance_valid(child) and child.size.y > 0:
			var port_y = child.global_position.y + child.size.y / 2.0
			return Vector2(global_position.x + side_x, port_y)
			
	# Otherwise (splitters or empty lists), calculate position mathematically based on sequential entry slots
	var header_height = float(cell_size) # 1 grid cell for header
	var start_y = global_position.y - half_height + header_height
	var end_y = global_position.y + half_height - 3.0 # 3px bottom padding
	
	var total_entries = in_count + out_count
	if total_entries <= 0:
		return Vector2(global_position.x + side_x, global_position.y)
		
	var entry_idx = (in_count + port_idx) if is_output else port_idx
	var step = (end_y - start_y) / float(total_entries)
	var port_y = start_y + (float(entry_idx) + 0.5) * step
	return Vector2(global_position.x + side_x, port_y)

## Determines output sub-port index based on mouse click global position.
func get_output_port_at_position(click_global_pos: Vector2) -> int:
	if data == null:
		return 0
	var recipe_ctx = {"inputs": data.inputs, "outputs": data.outputs}
	var total_ports = BuildingData.get_output_ports_count(data.type, recipe_ctx)
	if total_ports <= 1:
		return 0
		
	var best_idx = 0
	var best_dist = INF
	for i in range(total_ports):
		var port_pos = get_port_global_position(true, i)
		var dist = click_global_pos.distance_to(port_pos)
		if dist < best_dist:
			best_dist = dist
			best_idx = i
	return best_idx

## Helper function to calculate connection point (on building outer edge) toward another point
func get_connection_point_toward(target_pos: Vector2) -> Vector2:
	var my_center = global_position
	var dir = (target_pos - my_center).normalized()
	
	var half_width = data.size_in_cells.x * cell_size / 2.0
	var half_height = data.size_in_cells.y * cell_size / 2.0
	
	if dir.x == 0:
		return my_center + Vector2(0, signf(dir.y) * half_height)
		
	var t_x = half_width / absf(dir.x)
	var t_y = half_height / absf(dir.y)
	var t = minf(t_x, t_y)
	
	return my_center + dir * t
