extends Node2D
class_name BuildingVisual

## Visual representation of a building on the grid, syncing with BuildingData.

# Emitted when the building is clicked
signal clicked(building_id: int)

var data: BuildingData
var cell_size: int = 64
var is_selected: bool = false
var is_hovered: bool = false

# UI references
var panel: PanelContainer
var title_label: Label
var progress_bar: ProgressBar
var inputs_container: VBoxContainer
var outputs_container: VBoxContainer

# Styling Colors based on building type
var accent_color: Color = Color.WHITE

func setup(p_data: BuildingData, p_cell_size: int) -> void:
	data = p_data
	cell_size = p_cell_size
	
	# Determine colors based on type
	match data.type:
		"miner":
			accent_color = Color(0.9, 0.45, 0.1) # Amber / Orange
		"smelter":
			accent_color = Color(0.95, 0.25, 0.25) # Hot Red
		"constructor":
			accent_color = Color(0.2, 0.7, 0.9) # Cyan
		"seller":
			accent_color = Color(0.2, 0.85, 0.4) # Emerald Green
		_:
			accent_color = Color(0.7, 0.7, 0.7)
			
	# Set visual position (centered on grid cell)
	position = Vector2(data.grid_position) * cell_size + Vector2(cell_size / 2.0, cell_size / 2.0)
	
	_create_ui()
	_update_ui()

func _create_ui() -> void:
	# Create PanelContainer for the building block
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(110, 90)
	panel.position = Vector2(-55, -45) # Centered
	
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
	panel.add_theme_stylebox_override("panel", style)
	
	# Mouse filter to let MainGame handle selection clicks
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Inside panel: VBoxContainer
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)
	
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
	
	# ScrollContainer for buffers (optional, here we just use VBox)
	var buffers_hbox = HBoxContainer.new()
	buffers_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(buffers_hbox)
	
	# Left: Inputs list
	inputs_container = VBoxContainer.new()
	inputs_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buffers_hbox.add_child(inputs_container)
	
	# Right: Outputs list
	outputs_container = VBoxContainer.new()
	outputs_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buffers_hbox.add_child(outputs_container)
	
	add_child(panel)
	_set_mouse_ignore(panel)

func _set_mouse_ignore(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_ignore(child)


func _process(_delta: float) -> void:
	if data == null:
		return
	_update_ui()

func _update_ui() -> void:
	# Update progress bar
	if data.active_recipe.is_empty():
		progress_bar.visible = false
	else:
		progress_bar.visible = true
		var duration = float(data.active_recipe.get("duration", 1.0))
		progress_bar.max_value = duration
		progress_bar.value = data.production_progress
		
	# Update input and output buffer texts
	_update_resource_list(inputs_container, data.inputs, data.input_limits, true)
	_update_resource_list(outputs_container, data.outputs, data.output_limits, false)
	
	# Update glow/borders based on selection and hover
	var style = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		if is_selected:
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
	# Clear existing children if mismatch
	if container.get_child_count() != resources.size():
		for child in container.get_children():
			child.queue_free()
			container.remove_child(child)
		
		for res in resources:
			var lbl = Label.new()
			lbl.name = res
			lbl.add_theme_font_size_override("font_size", 9)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if is_input else HORIZONTAL_ALIGNMENT_RIGHT
			container.add_child(lbl)
			
	# Update text values
	for child in container.get_children():
		var res_name = child.name
		if resources.has(res_name):
			var val = resources[res_name]
			var limit = limits.get(res_name, 20.0)
			# Format resource name (first 3 chars or complete)
			var short_name = res_name.substr(0, 4)
			# Color coding for resources
			var col_tag = "[color=#ff8888]" if is_input else "[color=#88ff88]"
			child.text = "%s: %.1f" % [short_name, val]
			if is_input:
				child.add_theme_color_override("font_color", Color(0.8, 0.7, 0.7))
			else:
				child.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))

## Helper function to calculate connection point (on building outer edge) toward another point
func get_connection_point_toward(target_pos: Vector2) -> Vector2:
	var my_center = global_position
	var dir = (target_pos - my_center).normalized()
	
	# Bounding box of the panel
	var half_width = 55.0
	var half_height = 45.0
	
	# Find intersection of dir line with bounding box of size (110x90)
	if dir.x == 0:
		return my_center + Vector2(0, signf(dir.y) * half_height)
		
	var t_x = half_width / absf(dir.x)
	var t_y = half_height / absf(dir.y)
	var t = minf(t_x, t_y)
	
	return my_center + dir * t
