extends Node2D
class_name BuildingRenderer

## High-performance batched renderer for factory buildings using MultiMesh2D instancing and pre-baked procedural textures.
## Layer ordering (ALL z_index > 0):
## 1. Connection Lines (z_index = 1, drawn by ConnectionRenderer)
## 2. Ports of Standard Buildings (instanced via MultiMeshInstance2D, z_index = 2)
## 3. Background Panels (ALL buildings, instanced via MultiMeshInstance2D, z_index = 3)
## 4. Building Outlines, Progress Bars, Splitter Lines, Text (BuildingRenderer Node2D, z_index = 4)
## 5. Splitter Ports (instanced via MultiMeshInstance2D OVER splitter lines, z_index = 6)

class StaticUI extends Node2D:
	var parent: Node2D
	func _draw() -> void:
		if is_instance_valid(parent):
			parent._draw_static_layer(self)

class DynamicUI extends Node2D:
	var parent: Node2D
	func _draw() -> void:
		if is_instance_valid(parent):
			parent._draw_dynamic_layer(self)

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

var static_ui: StaticUI
var dynamic_ui: DynamicUI
var _static_dirty: bool = true

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

func request_static_redraw() -> void:
	_static_dirty = true

func mark_culling_dirty() -> void:
	_culling_dirty = true

func mark_borders_dirty() -> void:
	if is_instance_valid(dynamic_ui):
		dynamic_ui.queue_redraw()

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
		_panel_multimesh_instance.z_as_relative = false
		_panel_multimesh_instance.z_index = 3
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
		_in_ports_multimesh_instance.z_as_relative = false
		_in_ports_multimesh_instance.z_index = 2
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
		_out_ports_multimesh_instance.z_as_relative = false
		_out_ports_multimesh_instance.z_index = 2
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
		_splitter_in_ports_multimesh_instance.z_as_relative = false
		_splitter_in_ports_multimesh_instance.z_index = 6
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
		_splitter_out_ports_multimesh_instance.z_as_relative = false
		_splitter_out_ports_multimesh_instance.z_index = 6
		add_child(_splitter_out_ports_multimesh_instance)
		
		_splitter_out_ports_multimesh = MultiMesh.new()
		_splitter_out_ports_multimesh.transform_format = MultiMesh.TRANSFORM_2D
		_splitter_out_ports_multimesh.use_colors = true
		_splitter_out_ports_multimesh.mesh = _quad_mesh
		_splitter_out_ports_multimesh_instance.multimesh = _splitter_out_ports_multimesh

func setup(p_visuals_map: Dictionary, p_camera: GameCamera = null, p_cell_size: int = 32, p_hud: Node = null) -> void:
	z_as_relative = false
	z_index = 0
	visuals_map = p_visuals_map
	camera = p_camera
	cell_size = p_cell_size
	hud = p_hud
	_fallback_font = ThemeDB.fallback_font
	_last_camera_pos = Vector2.INF
	_last_camera_zoom = -1.0
	_culling_dirty = true
	_last_visuals_count = -1
	_static_dirty = true
	_init_ports_multimeshes()
	
	if static_ui == null:
		static_ui = StaticUI.new()
		static_ui.parent = self
		static_ui.z_as_relative = false
		static_ui.z_index = 4
		static_ui.name = "StaticUI"
		add_child(static_ui)
		
	if dynamic_ui == null:
		dynamic_ui = DynamicUI.new()
		dynamic_ui.parent = self
		dynamic_ui.z_as_relative = false
		dynamic_ui.z_index = 5
		dynamic_ui.name = "DynamicUI"
		add_child(dynamic_ui)

func _process(delta: float) -> void:
	if visuals_map.is_empty():
		return
		
	# Check camera changes for dirty redraw and frustum culling
	if is_instance_valid(camera):
		if camera.position != _last_camera_pos or camera.zoom.x != _last_camera_zoom:
			_last_camera_pos = camera.position
			_last_camera_zoom = camera.zoom.x
			_culling_dirty = true
			
	if visuals_map.size() != _last_visuals_count:
		_last_visuals_count = visuals_map.size()
		_culling_dirty = true
		_static_dirty = true
		
	var dynamic_needs_redraw = false
	
	# Process timers only on flashing visuals
	for vis in visuals_map.values():
		if is_instance_valid(vis):
			if vis.is_flashing and vis._process_port_flashes(delta):
				dynamic_needs_redraw = true
			if vis.data and not vis.data.is_portal and not vis.data.active_recipe.is_empty():
				if vis.data.production_progress > 0.0 or vis.data.production_progress != vis.data._cached_duration:
					# To be perfectly optimal we could track if progress actually changed this frame, 
					# but since factories run smoothly, it changes every tick/frame anyway.
					dynamic_needs_redraw = true
					
	if _culling_dirty:
		_culling_dirty = false
		_perform_culling_and_update_multimeshes()
		dynamic_needs_redraw = true # visible set changed, need to update dynamic UI
		
	if _static_dirty:
		_static_dirty = false
		if is_instance_valid(static_ui):
			static_ui.queue_redraw()
			
	if dynamic_needs_redraw and is_instance_valid(dynamic_ui):
		dynamic_ui.queue_redraw()

func _perform_culling_and_update_multimeshes() -> void:
	var view_rect = camera.get_visible_world_rect(128.0) if is_instance_valid(camera) else Rect2(-99999, -99999, 199998, 199998)
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
		
	if _cached_visible_visuals.is_empty():
		if _panel_multimesh != null: _panel_multimesh.visible_instance_count = 0
		if _in_ports_multimesh != null: _in_ports_multimesh.visible_instance_count = 0
		if _out_ports_multimesh != null: _out_ports_multimesh.visible_instance_count = 0
		if _splitter_in_ports_multimesh != null: _splitter_in_ports_multimesh.visible_instance_count = 0
		if _splitter_out_ports_multimesh != null: _splitter_out_ports_multimesh.visible_instance_count = 0
		return
		
	_update_panel_multimesh(_cached_visible_visuals)
	_update_std_ports_multimesh(_cached_std_visuals)
	_update_splitter_ports_multimesh(_cached_splitter_visuals)

func _update_panel_multimesh(visible_visuals: Array[BuildingVisual]) -> void:
	_init_panel_multimesh()
	var count = visible_visuals.size()
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
		
	if _in_ports_multimesh.instance_count < in_count: _in_ports_multimesh.instance_count = max(in_count + 128, 256)
	_in_ports_multimesh.visible_instance_count = in_count
	
	if _out_ports_multimesh.instance_count < out_count: _out_ports_multimesh.instance_count = max(out_count + 128, 256)
	_out_ports_multimesh.visible_instance_count = out_count
	
	var port_scale = Vector2(11.0, 11.0)
	var white_color = Color.WHITE
	
	var in_idx = 0
	var out_idx = 0
	for vis in std_visuals:
		var g_pos = vis.global_position
		for pt in vis._cached_in_ports_local:
			_in_ports_multimesh.set_instance_transform_2d(in_idx, Transform2D(0.0, port_scale, 0.0, g_pos + pt))
			_in_ports_multimesh.set_instance_color(in_idx, white_color)
			in_idx += 1
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
		
	if _splitter_in_ports_multimesh.instance_count < in_count: _splitter_in_ports_multimesh.instance_count = max(in_count + 32, 64)
	_splitter_in_ports_multimesh.visible_instance_count = in_count
	
	if _splitter_out_ports_multimesh.instance_count < out_count: _splitter_out_ports_multimesh.instance_count = max(out_count + 32, 64)
	_splitter_out_ports_multimesh.visible_instance_count = out_count
	
	var port_scale = Vector2(11.0, 11.0)
	var white_color = Color.WHITE
	
	var in_idx = 0
	var out_idx = 0
	for vis in splitter_visuals:
		var g_pos = vis.global_position
		for pt in vis._cached_in_ports_local:
			_splitter_in_ports_multimesh.set_instance_transform_2d(in_idx, Transform2D(0.0, port_scale, 0.0, g_pos + pt))
			_splitter_in_ports_multimesh.set_instance_color(in_idx, white_color)
			in_idx += 1
		for pt in vis._cached_out_ports_local:
			_splitter_out_ports_multimesh.set_instance_transform_2d(out_idx, Transform2D(0.0, port_scale, 0.0, g_pos + pt))
			_splitter_out_ports_multimesh.set_instance_color(out_idx, white_color)
			out_idx += 1

func _draw_static_layer(canvas: CanvasItem) -> void:
	if visuals_map.is_empty():
		return
		
	var font = _fallback_font
	if font == null: font = ThemeDB.fallback_font
	
	var all_visuals = []
	for vis in visuals_map.values():
		if is_instance_valid(vis) and not vis.is_selected and not vis.is_dragged:
			all_visuals.append(vis)
			
	var std_visuals: Array[BuildingVisual] = []
	for vis in all_visuals:
		if vis.data and not vis.data.is_splitter:
			std_visuals.append(vis)
			
	# Base Borders (NO CULLING)
	var temp_groups: Dictionary = {}
	for vis in all_visuals:
		if not is_instance_valid(vis) or vis.data == null: continue
		var size_px = Vector2(vis.data.size_in_cells * vis.cell_size)
		var top_left = vis.global_position - size_px / 2.0
		var rect = Rect2(top_left, size_px)
		var border_color = vis.accent_color.darkened(0.3)
		var border_width = 2.0
		if not temp_groups.has(border_color):
			temp_groups[border_color] = { "rects": [], "width": border_width }
		(temp_groups[border_color]["rects"] as Array).append(rect)
		
	for col in temp_groups:
		var group = temp_groups[col]
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
		canvas.draw_multiline(pts, col, width)
		
	# Text (NO CULLING for static layer)
	if font != null:
		_draw_building_text(canvas, std_visuals, font)

func _draw_building_text(canvas: CanvasItem, std_visuals: Array[BuildingVisual], font: Font) -> void:
	var std_count = std_visuals.size()
	if std_count == 0:
		return
		
	var top_lefts: Array[Vector2] = []
	var sizes_px: Array[Vector2] = []
	top_lefts.resize(std_count)
	sizes_px.resize(std_count)
	
	for idx in range(std_count):
		var vis = std_visuals[idx]
		var sz = Vector2(vis.data.size_in_cells * vis.cell_size)
		sizes_px[idx] = sz
		top_lefts[idx] = vis.global_position - sz * 0.5

	# Title Text Fills
	for idx in range(std_count):
		var vis = std_visuals[idx]
		canvas.draw_string(font, Vector2(top_lefts[idx].x, top_lefts[idx].y + 14.0), vis._cached_title_str, HORIZONTAL_ALIGNMENT_CENTER, sizes_px[idx].x, 11, vis.accent_color)
		
	# Resource Input Fills
	var in_fill_color = Color(0.85, 0.75, 0.75)
	for idx in range(std_count):
		var vis = std_visuals[idx]
		var in_lines = vis._cached_in_text_lines
		var in_count = in_lines.size()
		if in_count > 0:
			var tl = top_lefts[idx]
			var sz = sizes_px[idx]
			var g_pos = vis.global_position
			var cached_ports = vis._cached_in_ports_local
			var port_count = cached_ports.size()
			var avail_w = sz.x - 8.0
			for i in range(in_count):
				var line_y: float
				if i < port_count:
					line_y = g_pos.y + cached_ports[i].y + 3.0
				else:
					var start_y = tl.y + float(vis.cell_size)
					var avail_height = sz.y - float(vis.cell_size) - 3.0
					var step = avail_height / float(max(1, in_count))
					line_y = start_y + (i + 0.5) * step + 3.0
				canvas.draw_string(font, Vector2(tl.x + 4.0, line_y), in_lines[i], HORIZONTAL_ALIGNMENT_LEFT, avail_w, 9, in_fill_color)

	# Resource Output Fills
	var out_fill_color = Color(0.75, 0.85, 0.75)
	for idx in range(std_count):
		var vis = std_visuals[idx]
		var out_lines = vis._cached_out_text_lines
		var out_count = out_lines.size()
		if out_count > 0:
			var tl = top_lefts[idx]
			var sz = sizes_px[idx]
			var g_pos = vis.global_position
			var cached_ports = vis._cached_out_ports_local
			var port_count = cached_ports.size()
			var avail_w = sz.x - 8.0
			for i in range(out_count):
				var line_y: float
				if i < port_count:
					line_y = g_pos.y + cached_ports[i].y + 3.0
				else:
					var start_y = tl.y + float(vis.cell_size)
					var avail_height = sz.y - float(vis.cell_size) - 3.0
					var step = avail_height / float(max(1, out_count))
					line_y = start_y + (i + 0.5) * step + 3.0
				canvas.draw_string(font, Vector2(tl.x + 4.0, line_y), out_lines[i], HORIZONTAL_ALIGNMENT_RIGHT, avail_w, 9, out_fill_color)

func _draw_dynamic_layer(canvas: CanvasItem) -> void:
	if _cached_visible_visuals.is_empty():
		return
		
	var current_zoom = camera.zoom.x if is_instance_valid(camera) else 1.0
	var is_low_lod = (current_zoom < 0.45)
	
	# Dynamic Borders (Hovered / Selected / Invalid Drag / Dragged)
	var temp_groups: Dictionary = {}
	for vis in _cached_visible_visuals:
		if vis.is_invalid_drag or vis.is_selected or vis.is_hovered or vis.is_dragged:
			var size_px = Vector2(vis.data.size_in_cells * vis.cell_size)
			var top_left = vis.global_position - size_px / 2.0
			var rect = Rect2(top_left, size_px)
			var border_color = vis.accent_color
			var border_width = 2.0
			
			if vis.is_invalid_drag:
				border_color = Color(0.9, 0.25, 0.25)
				border_width = 3.0
			elif vis.is_selected or vis.is_dragged:
				border_color = Color(1.0, 0.9, 0.3)
				border_width = 3.0
			elif vis.is_hovered:
				border_color = vis.accent_color.lightened(0.2)
				border_width = 2.0
				
			if not temp_groups.has(border_color):
				temp_groups[border_color] = { "rects": [], "width": border_width }
			(temp_groups[border_color]["rects"] as Array).append(rect)
			
	for col in temp_groups:
		var group = temp_groups[col]
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
		canvas.draw_multiline(pts, col, width)
		
	# Progress Bars
	if not is_low_lod:
		var pb_bg_color = Color(0.04, 0.05, 0.06, 1.0)
		for vis in _cached_std_visuals:
			var data = vis.data
			if data.is_portal or data.active_recipe.is_empty(): continue
				
			var duration = float(data._cached_duration)
			var size_px = Vector2(data.size_in_cells * vis.cell_size)
			var top_left = vis.global_position - size_px / 2.0
			var bar_margin_x = 4.0
			var bar_y = top_left.y + 18.0
			var bar_width = size_px.x - bar_margin_x * 2.0
			
			if bar_width > 4.0:
				canvas.draw_rect(Rect2(top_left.x + bar_margin_x, bar_y, bar_width, 5.0), pb_bg_color, true)
				if duration > 0.0:
					var fill_ratio = clampf(data.production_progress / duration, 0.0, 1.0)
					if fill_ratio > 0.0:
						canvas.draw_rect(Rect2(top_left.x + bar_margin_x, bar_y, bar_width * fill_ratio, 5.0), vis.accent_color, true)
						
	# Selected Building Text (Dynamic)
	var font = _fallback_font
	if font == null: font = ThemeDB.fallback_font
	if font != null:
		var selected_std_visuals: Array[BuildingVisual] = []
		for vis in _cached_visible_visuals:
			if (vis.is_selected or vis.is_dragged) and vis.data and not vis.data.is_splitter:
				selected_std_visuals.append(vis)
		if selected_std_visuals.size() > 0:
			_draw_building_text(canvas, selected_std_visuals, font)
	for vis in _cached_splitter_visuals:
		var in_pt = vis.global_position + vis._cached_in_ports_local[0] if vis._cached_in_ports_local.size() > 0 else vis.global_position
		var out_count = vis._cached_out_ports_local.size()
		for i in range(out_count):
			var out_pt = vis.global_position + vis._cached_out_ports_local[i]
			var is_flashing = (i < vis.port_flash_timers.size() and vis.port_flash_timers[i] > 0.0)
			if is_flashing:
				var alpha = minf(1.0, vis.port_flash_timers[i] / 0.15)
				canvas.draw_line(in_pt, out_pt, Color(1.0, 0.85, 0.2, alpha * 0.7), 6.0)
				canvas.draw_line(in_pt, out_pt, Color(1.0, 1.0, 0.7, alpha), 3.0)
			else:
				canvas.draw_line(in_pt, out_pt, Color(0.35, 0.4, 0.45, 0.7), 2.0)
