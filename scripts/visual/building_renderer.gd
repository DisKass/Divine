extends Node2D
class_name BuildingRenderer

## High-performance batched renderer for factory buildings using MultiMesh2D instancing and pre-baked procedural textures.
## Layer ordering:
## 1. Ports of Standard Buildings (instanced via MultiMeshInstance2D behind panels, z_index = -2)
## 2. Background Panels (ALL buildings, instanced via MultiMeshInstance2D on GPU in 1 Draw Call, z_index = -1)
## 3. Borders (ALL buildings, grouped by color using single draw_multiline calls for 100% GPU batching)
## 4. Progress Bars (Standard buildings)
## 5. Splitter Flow Lines (OVER splitters)
## 6. Splitter Ports (instanced via MultiMeshInstance2D OVER splitter lines, z_index = 2)
## 7. Title & Resource Text (Contiguous passes using cached text strings)

var visuals_map: Dictionary = {}
var camera: GameCamera
var hud: Node
var cell_size: int = 32

var _fallback_font: Font
var _blue_port_texture: Texture2D
var _yellow_port_texture: Texture2D
var _panel_texture: Texture2D

var _last_camera_pos: Vector2 = Vector2.INF
var _last_camera_zoom: float = -1.0
var _culling_dirty: bool = true
var _last_visuals_count: int = -1

var _cached_visible_visuals: Array[BuildingVisual] = []
var _cached_std_visuals: Array[BuildingVisual] = []
var _cached_splitter_visuals: Array[BuildingVisual] = []

var _panel_multimesh_instance: MultiMeshInstance2D
var _panel_multimesh: MultiMesh
var _quad_mesh: QuadMesh

var _in_ports_multimesh_instance: MultiMeshInstance2D
var _in_ports_multimesh: MultiMesh

var _out_ports_multimesh_instance: MultiMeshInstance2D
var _out_ports_multimesh: MultiMesh

var _splitter_in_ports_multimesh_instance: MultiMeshInstance2D
var _splitter_in_ports_multimesh: MultiMesh

var _splitter_out_ports_multimesh_instance: MultiMeshInstance2D
var _splitter_out_ports_multimesh: MultiMesh

func mark_culling_dirty() -> void:
	_culling_dirty = true
	queue_redraw()

func _generate_baked_port_texture(inner_color: Color) -> Texture2D:
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var center = Vector2(16.0, 16.0)
	var outer_radius = 14.5
	var inner_radius = 8.0
	
	for y in range(32):
		for x in range(32):
			var dist = Vector2(x + 0.5, y + 0.5).distance_to(center)
			if dist <= outer_radius + 1.0:
				var outer_alpha = clampf(outer_radius + 1.0 - dist, 0.0, 1.0)
				if dist <= inner_radius:
					img.set_pixel(x, y, inner_color)
				elif dist <= inner_radius + 1.0:
					var t = clampf(dist - inner_radius, 0.0, 1.0)
					var col = inner_color.lerp(Color.BLACK, t)
					col.a = outer_alpha
					img.set_pixel(x, y, col)
				else:
					img.set_pixel(x, y, Color(0, 0, 0, outer_alpha))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				
	return ImageTexture.create_from_image(img)

func _init_baked_textures() -> void:
	if _blue_port_texture == null:
		_blue_port_texture = _generate_baked_port_texture(Color(0.3, 0.7, 1.0, 0.9))
	if _yellow_port_texture == null:
		_yellow_port_texture = _generate_baked_port_texture(Color(1.0, 0.85, 0.2, 0.9))
	if _panel_texture == null:
		var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.08, 0.1, 0.12, 0.95))
		_panel_texture = ImageTexture.create_from_image(img)

func _init_panel_multimesh() -> void:
	_init_baked_textures()
	if _panel_multimesh_instance == null:
		_panel_multimesh_instance = MultiMeshInstance2D.new()
		_panel_multimesh_instance.name = "PanelMultiMeshInstance"
		_panel_multimesh_instance.texture = _panel_texture
		_panel_multimesh_instance.z_index = -1
		add_child(_panel_multimesh_instance)
		
		_quad_mesh = QuadMesh.new()
		_quad_mesh.size = Vector2(1.0, 1.0)
		
		_panel_multimesh = MultiMesh.new()
		_panel_multimesh.transform_format = MultiMesh.TRANSFORM_2D
		_panel_multimesh.use_colors = true
		_panel_multimesh.mesh = _quad_mesh
		_panel_multimesh_instance.multimesh = _panel_multimesh

func _init_ports_multimeshes() -> void:
	_init_panel_multimesh()
	
	if _in_ports_multimesh_instance == null:
		_in_ports_multimesh_instance = MultiMeshInstance2D.new()
		_in_ports_multimesh_instance.name = "InPortsMultiMeshInstance"
		_in_ports_multimesh_instance.texture = _blue_port_texture
		_in_ports_multimesh_instance.z_index = -2
		add_child(_in_ports_multimesh_instance)
		
		_in_ports_multimesh = MultiMesh.new()
		_in_ports_multimesh.transform_format = MultiMesh.TRANSFORM_2D
		_in_ports_multimesh.use_colors = true
		_in_ports_multimesh.mesh = _quad_mesh
		_in_ports_multimesh_instance.multimesh = _in_ports_multimesh
		
	if _out_ports_multimesh_instance == null:
		_out_ports_multimesh_instance = MultiMeshInstance2D.new()
		_out_ports_multimesh_instance.name = "OutPortsMultiMeshInstance"
		_out_ports_multimesh_instance.texture = _yellow_port_texture
		_out_ports_multimesh_instance.z_index = -2
		add_child(_out_ports_multimesh_instance)
		
		_out_ports_multimesh = MultiMesh.new()
		_out_ports_multimesh.transform_format = MultiMesh.TRANSFORM_2D
		_out_ports_multimesh.use_colors = true
		_out_ports_multimesh.mesh = _quad_mesh
		_out_ports_multimesh_instance.multimesh = _out_ports_multimesh
		
	if _splitter_in_ports_multimesh_instance == null:
		_splitter_in_ports_multimesh_instance = MultiMeshInstance2D.new()
		_splitter_in_ports_multimesh_instance.name = "SplitterInPortsMultiMeshInstance"
		_splitter_in_ports_multimesh_instance.texture = _blue_port_texture
		_splitter_in_ports_multimesh_instance.z_index = 2
		add_child(_splitter_in_ports_multimesh_instance)
		
		_splitter_in_ports_multimesh = MultiMesh.new()
		_splitter_in_ports_multimesh.transform_format = MultiMesh.TRANSFORM_2D
		_splitter_in_ports_multimesh.use_colors = true
		_splitter_in_ports_multimesh.mesh = _quad_mesh
		_splitter_in_ports_multimesh_instance.multimesh = _splitter_in_ports_multimesh
		
	if _splitter_out_ports_multimesh_instance == null:
		_splitter_out_ports_multimesh_instance = MultiMeshInstance2D.new()
		_splitter_out_ports_multimesh_instance.name = "SplitterOutPortsMultiMeshInstance"
		_splitter_out_ports_multimesh_instance.texture = _yellow_port_texture
		_splitter_out_ports_multimesh_instance.z_index = 2
		add_child(_splitter_out_ports_multimesh_instance)
		
		_splitter_out_ports_multimesh = MultiMesh.new()
		_splitter_out_ports_multimesh.transform_format = MultiMesh.TRANSFORM_2D
		_splitter_out_ports_multimesh.use_colors = true
		_splitter_out_ports_multimesh.mesh = _quad_mesh
		_splitter_out_ports_multimesh_instance.multimesh = _splitter_out_ports_multimesh

func setup(p_visuals_map: Dictionary, p_camera: GameCamera = null, p_cell_size: int = 32, p_hud: Node = null) -> void:
	visuals_map = p_visuals_map
	camera = p_camera
	cell_size = p_cell_size
	hud = p_hud
	_fallback_font = ThemeDB.fallback_font
	_last_camera_pos = Vector2.INF
	_last_camera_zoom = -1.0
	_culling_dirty = true
	_last_visuals_count = -1
	_init_ports_multimeshes()

func _process(delta: float) -> void:
	if visuals_map.is_empty():
		return
		
	var needs_redraw = false
	
	# Check camera changes for dirty redraw and frustum culling
	if is_instance_valid(camera):
		if camera.position != _last_camera_pos or camera.zoom.x != _last_camera_zoom:
			_last_camera_pos = camera.position
			_last_camera_zoom = camera.zoom.x
			_culling_dirty = true
			needs_redraw = true
			
	if visuals_map.size() != _last_visuals_count:
		_last_visuals_count = visuals_map.size()
		_culling_dirty = true
		needs_redraw = true
			
	# Process timers only on flashing visuals
	for vis in visuals_map.values():
		if is_instance_valid(vis) and vis.is_flashing:
			if vis._process_port_flashes(delta):
				needs_redraw = true
				
	if needs_redraw:
		queue_redraw()

func _update_panel_multimesh(visible_visuals: Array[BuildingVisual]) -> void:
	_init_panel_multimesh()
	var count = visible_visuals.size()
	if count == 0:
		_panel_multimesh.visible_instance_count = 0
		return
		
	if _panel_multimesh.instance_count < count:
		_panel_multimesh.instance_count = max(count + 128, 256)
		
	_panel_multimesh.visible_instance_count = count
	var white_color = Color.WHITE
	
	for i in range(count):
		var vis = visible_visuals[i]
		var size_px = Vector2(vis.data.size_in_cells * vis.cell_size)
		var xform = Transform2D(0.0, size_px, 0.0, vis.global_position)
		_panel_multimesh.set_instance_transform_2d(i, xform)
		_panel_multimesh.set_instance_color(i, white_color)

func _update_std_ports_multimesh(std_visuals: Array[BuildingVisual]) -> void:
	_init_ports_multimeshes()
	var in_count = 0
	var out_count = 0
	for vis in std_visuals:
		in_count += vis._cached_in_ports_local.size()
		out_count += vis._cached_out_ports_local.size()
		
	if _in_ports_multimesh.instance_count < in_count:
		_in_ports_multimesh.instance_count = max(in_count + 128, 256)
	_in_ports_multimesh.visible_instance_count = in_count
	
	if _out_ports_multimesh.instance_count < out_count:
		_out_ports_multimesh.instance_count = max(out_count + 128, 256)
	_out_ports_multimesh.visible_instance_count = out_count
	
	var port_scale = Vector2(11.0, 11.0)
	var white_color = Color.WHITE
	
	var in_idx = 0
	var out_idx = 0
	for vis in std_visuals:
		var g_pos = vis.global_position
		
		# In ports
		for pt in vis._cached_in_ports_local:
			_in_ports_multimesh.set_instance_transform_2d(in_idx, Transform2D(0.0, port_scale, 0.0, g_pos + pt))
			_in_ports_multimesh.set_instance_color(in_idx, white_color)
			in_idx += 1
			
		# Out ports
		for pt in vis._cached_out_ports_local:
			_out_ports_multimesh.set_instance_transform_2d(out_idx, Transform2D(0.0, port_scale, 0.0, g_pos + pt))
			_out_ports_multimesh.set_instance_color(out_idx, white_color)
			out_idx += 1

func _update_splitter_ports_multimesh(splitter_visuals: Array[BuildingVisual]) -> void:
	_init_ports_multimeshes()
	var in_count = 0
	var out_count = 0
	for vis in splitter_visuals:
		in_count += vis._cached_in_ports_local.size()
		out_count += vis._cached_out_ports_local.size()
		
	if _splitter_in_ports_multimesh.instance_count < in_count:
		_splitter_in_ports_multimesh.instance_count = max(in_count + 32, 64)
	_splitter_in_ports_multimesh.visible_instance_count = in_count
	
	if _splitter_out_ports_multimesh.instance_count < out_count:
		_splitter_out_ports_multimesh.instance_count = max(out_count + 32, 64)
	_splitter_out_ports_multimesh.visible_instance_count = out_count
	
	var port_scale = Vector2(11.0, 11.0)
	var white_color = Color.WHITE
	
	var in_idx = 0
	var out_idx = 0
	for vis in splitter_visuals:
		var g_pos = vis.global_position
		
		# In ports
		for pt in vis._cached_in_ports_local:
			_splitter_in_ports_multimesh.set_instance_transform_2d(in_idx, Transform2D(0.0, port_scale, 0.0, g_pos + pt))
			_splitter_in_ports_multimesh.set_instance_color(in_idx, white_color)
			in_idx += 1
			
		# Out ports
		for pt in vis._cached_out_ports_local:
			_splitter_out_ports_multimesh.set_instance_transform_2d(out_idx, Transform2D(0.0, port_scale, 0.0, g_pos + pt))
			_splitter_out_ports_multimesh.set_instance_color(out_idx, white_color)
			out_idx += 1

func _draw() -> void:
	if visuals_map.is_empty():
		if _panel_multimesh != null:
			_panel_multimesh.visible_instance_count = 0
		if _in_ports_multimesh != null:
			_in_ports_multimesh.visible_instance_count = 0
		if _out_ports_multimesh != null:
			_out_ports_multimesh.visible_instance_count = 0
		if _splitter_in_ports_multimesh != null:
			_splitter_in_ports_multimesh.visible_instance_count = 0
		if _splitter_out_ports_multimesh != null:
			_splitter_out_ports_multimesh.visible_instance_count = 0
		return
		
	var font = _fallback_font
	if font == null:
		font = ThemeDB.fallback_font
		
	var view_rect = camera.get_visible_world_rect(128.0) if is_instance_valid(camera) else Rect2(-99999, -99999, 199998, 199998)
	var current_zoom = camera.zoom.x if is_instance_valid(camera) else 1.0
	var is_low_lod = (current_zoom < 0.45)
	
	# Collect visible building visuals (Frustum Culling) only when dirty
	if _culling_dirty or _last_visuals_count != visuals_map.size():
		_culling_dirty = false
		_last_visuals_count = visuals_map.size()
		_cached_visible_visuals.clear()
		_cached_std_visuals.clear()
		_cached_splitter_visuals.clear()
		
		for vis in visuals_map.values():
			if not is_instance_valid(vis) or vis.data == null:
				continue
				
			var size_px = Vector2(vis.data.size_in_cells * vis.cell_size)
			var half_size = size_px * 0.5
			var my_min = vis.global_position - half_size
			var my_max = vis.global_position + half_size
			
			var is_in_view = not (my_max.x < view_rect.position.x or my_min.x > view_rect.end.x or \
								  my_max.y < view_rect.position.y or my_min.y > view_rect.end.y)
								  
			vis.visible = is_in_view
			if is_in_view:
				_cached_visible_visuals.append(vis)
				if vis.data.is_splitter:
					_cached_splitter_visuals.append(vis)
				else:
					_cached_std_visuals.append(vis)
					
		if is_instance_valid(hud) and hud.has_method("update_culling_stats"):
			hud.update_culling_stats(_cached_visible_visuals.size(), visuals_map.size())
			
	var visible_visuals = _cached_visible_visuals
	var std_visuals = _cached_std_visuals
	var splitter_visuals = _cached_splitter_visuals
	
	if visible_visuals.is_empty():
		if _panel_multimesh != null:
			_panel_multimesh.visible_instance_count = 0
		if _in_ports_multimesh != null:
			_in_ports_multimesh.visible_instance_count = 0
		if _out_ports_multimesh != null:
			_out_ports_multimesh.visible_instance_count = 0
		if _splitter_in_ports_multimesh != null:
			_splitter_in_ports_multimesh.visible_instance_count = 0
		if _splitter_out_ports_multimesh != null:
			_splitter_out_ports_multimesh.visible_instance_count = 0
		return

	# Update MultiMesh GPU buffer for background panels (1 Draw Call!)
	_update_panel_multimesh(visible_visuals)

	# Update MultiMesh GPU buffers for pre-baked procedural ports
	_update_std_ports_multimesh(std_visuals)
	_update_splitter_ports_multimesh(splitter_visuals)

	# =========================================================================
	# LAYER 2: Building Borders / Outlines (Batched into 1 draw_multiline per color)
	# =========================================================================
	var border_groups: Dictionary = {} # Color -> Dictionary { "rects": Array[Rect2], "width": float }
	
	for vis in visible_visuals:
		var size_px = Vector2(vis.data.size_in_cells * vis.cell_size)
		var top_left = vis.global_position - size_px / 2.0
		var rect = Rect2(top_left, size_px)
		
		var border_color = vis.accent_color.darkened(0.3)
		var border_width = 2.0
		
		if vis.is_invalid_drag:
			border_color = Color(0.9, 0.25, 0.25)
			border_width = 3.0
		elif vis.is_selected:
			border_color = Color(1.0, 0.9, 0.3)
			border_width = 3.0
		elif vis.is_hovered:
			border_color = vis.accent_color.lightened(0.2)
			border_width = 2.0
			
		if not border_groups.has(border_color):
			border_groups[border_color] = { "rects": [], "width": border_width }
		(border_groups[border_color]["rects"] as Array).append(rect)
		
	# Draw each color group using a single draw_multiline call
	for col in border_groups:
		var group = border_groups[col]
		var col_rects: Array = group["rects"]
		var width: float = group["width"]
		
		var pts = PackedVector2Array()
		pts.resize(col_rects.size() * 8)
		var idx = 0
		for r in col_rects:
			var tl = r.position
			var tr = Vector2(r.end.x, r.position.y)
			var br = r.end
			var bl = Vector2(r.position.x, r.end.y)
			
			pts[idx] = tl;     pts[idx + 1] = tr
			pts[idx + 2] = tr; pts[idx + 3] = br
			pts[idx + 4] = br; pts[idx + 5] = bl
			pts[idx + 6] = bl; pts[idx + 7] = tl
			idx += 8
			
		draw_multiline(pts, col, width)

	# =========================================================================
	# LAYER 3: Progress Bars (Standard Buildings)
	# =========================================================================
	if not is_low_lod:
		# 3A: Progress Bar Backgrounds
		var pb_bg_color = Color(0.04, 0.05, 0.06, 1.0)
		for vis in std_visuals:
			var data = vis.data
			if data.is_portal or data.active_recipe.is_empty():
				continue
			var size_px = Vector2(data.size_in_cells * vis.cell_size)
			var top_left = vis.global_position - size_px / 2.0
			var bar_margin_x = 4.0
			var bar_y = top_left.y + 18.0
			var bar_width = size_px.x - bar_margin_x * 2.0
			if bar_width > 4.0:
				draw_rect(Rect2(top_left.x + bar_margin_x, bar_y, bar_width, 5.0), pb_bg_color, true)
				
		# 3B: Progress Bar Fills
		for vis in std_visuals:
			var data = vis.data
			if data.is_portal or data.active_recipe.is_empty():
				continue
			var duration = float(data._cached_duration)
			if duration <= 0.0:
				continue
			var fill_ratio = clampf(data.production_progress / duration, 0.0, 1.0)
			if fill_ratio <= 0.0:
				continue
			var size_px = Vector2(data.size_in_cells * vis.cell_size)
			var top_left = vis.global_position - size_px / 2.0
			var bar_margin_x = 4.0
			var bar_y = top_left.y + 18.0
			var bar_width = size_px.x - bar_margin_x * 2.0
			if bar_width > 4.0:
				draw_rect(Rect2(top_left.x + bar_margin_x, bar_y, bar_width * fill_ratio, 5.0), vis.accent_color, true)

	# =========================================================================
	# LAYER 4: Internal Lines on Splitters
	# =========================================================================
	for vis in splitter_visuals:
		var in_pt = vis.global_position + vis._cached_in_ports_local[0] if vis._cached_in_ports_local.size() > 0 else vis.global_position
		var out_count = vis._cached_out_ports_local.size()
		for i in range(out_count):
			var out_pt = vis.global_position + vis._cached_out_ports_local[i]
			var is_flashing = (i < vis.port_flash_timers.size() and vis.port_flash_timers[i] > 0.0)
			if is_flashing:
				var alpha = minf(1.0, vis.port_flash_timers[i] / 0.15)
				draw_line(in_pt, out_pt, Color(1.0, 0.85, 0.2, alpha * 0.7), 6.0)
				draw_line(in_pt, out_pt, Color(1.0, 1.0, 0.7, alpha), 3.0)
			else:
				draw_line(in_pt, out_pt, Color(0.35, 0.4, 0.45, 0.7), 2.0)

	# =========================================================================
	# LAYER 5: Text (Titles & Resource Lists using pre-cached text strings)
	# =========================================================================
	if not is_low_lod and font != null:
		# 5A: Title Outlines
		for vis in std_visuals:
			var size_px = Vector2(vis.data.size_in_cells * vis.cell_size)
			var top_left = vis.global_position - size_px / 2.0
			_draw_title_text_pass(vis, font, top_left, size_px, true)
			
		# 5B: Title Text Fills
		for vis in std_visuals:
			var size_px = Vector2(vis.data.size_in_cells * vis.cell_size)
			var top_left = vis.global_position - size_px / 2.0
			_draw_title_text_pass(vis, font, top_left, size_px, false)
			
		# 5C: Resource Text Outlines
		for vis in std_visuals:
			var size_px = Vector2(vis.data.size_in_cells * vis.cell_size)
			var top_left = vis.global_position - size_px / 2.0
			_draw_resource_text_pass(vis, font, top_left, size_px, true)

		# 5D: Resource Text Fills
		for vis in std_visuals:
			var size_px = Vector2(vis.data.size_in_cells * vis.cell_size)
			var top_left = vis.global_position - size_px / 2.0
			_draw_resource_text_pass(vis, font, top_left, size_px, false)

func _draw_title_text_pass(vis: BuildingVisual, font: Font, top_left: Vector2, size_px: Vector2, is_outline: bool) -> void:
	var title_str = vis._cached_title_str
	var title_pos = Vector2(top_left.x, top_left.y + 14.0)
	if is_outline:
		draw_string_outline(font, title_pos, title_str, HORIZONTAL_ALIGNMENT_CENTER, size_px.x, 11, 2, Color.BLACK)
	else:
		draw_string(font, title_pos, title_str, HORIZONTAL_ALIGNMENT_CENTER, size_px.x, 11, vis.accent_color)

func _draw_resource_text_pass(vis: BuildingVisual, font: Font, top_left: Vector2, size_px: Vector2, is_outline: bool) -> void:
	var in_lines = vis._cached_in_text_lines
	var out_lines = vis._cached_out_text_lines
	var in_count = in_lines.size()
	var out_count = out_lines.size()
	
	var start_y = top_left.y + 26.0
	var avail_height = size_px.y - 28.0
	if avail_height < 10.0:
		return
		
	# Draw inputs (left side)
	if in_count > 0:
		var in_step = avail_height / float(max(1, in_count))
		for i in range(in_count):
			var txt = in_lines[i]
			var line_pos = Vector2(top_left.x + 4.0, start_y + (i + 0.7) * in_step)
			if is_outline:
				draw_string_outline(font, line_pos, txt, HORIZONTAL_ALIGNMENT_LEFT, size_px.x * 0.48, 9, 2, Color.BLACK)
			else:
				draw_string(font, line_pos, txt, HORIZONTAL_ALIGNMENT_LEFT, size_px.x * 0.48, 9, Color(0.85, 0.75, 0.75))
			
	# Draw outputs (right side)
	if out_count > 0:
		var out_step = avail_height / float(max(1, out_count))
		for i in range(out_count):
			var txt = out_lines[i]
			var line_pos = Vector2(top_left.x + size_px.x * 0.5, start_y + (i + 0.7) * out_step)
			if is_outline:
				draw_string_outline(font, line_pos, txt, HORIZONTAL_ALIGNMENT_RIGHT, size_px.x * 0.48, 9, 2, Color.BLACK)
			else:
				draw_string(font, line_pos, txt, HORIZONTAL_ALIGNMENT_RIGHT, size_px.x * 0.48, 9, Color(0.75, 0.85, 0.75))
