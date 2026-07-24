extends Node2D
class_name BuildingRenderer

## High-performance batched renderer for factory buildings.
## Layer ordering:
## 1. Ports of Standard Buildings (drawn BEFORE building backgrounds/borders so inner half is covered)
## 2. Background Panels (ALL buildings)
## 3. Borders (ALL buildings, grouped by color using single draw_multiline calls for 100% GPU batching)
## 4. Progress Bars (Standard buildings)
## 5. Splitter Flow Lines (OVER splitters)
## 6. Splitter Ports (OVER splitter lines)
## 7. Title & Resource Text (Contiguous passes using cached text strings)

var visuals_map: Dictionary = {}
var camera: GameCamera
var hud: Node
var cell_size: int = 32

var _fallback_font: Font
var _circle_texture: Texture2D

var _last_camera_pos: Vector2 = Vector2.INF
var _last_camera_zoom: float = -1.0

func setup(p_visuals_map: Dictionary, p_camera: GameCamera = null, p_cell_size: int = 32, p_hud: Node = null) -> void:
	visuals_map = p_visuals_map
	camera = p_camera
	cell_size = p_cell_size
	hud = p_hud
	_fallback_font = ThemeDB.fallback_font
	_last_camera_pos = Vector2.INF
	_last_camera_zoom = -1.0

func _get_circle_texture() -> Texture2D:
	if _circle_texture == null:
		var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		var center = Vector2(16, 16)
		var radius = 14.5
		for y in range(32):
			for x in range(32):
				var dist = Vector2(x + 0.5, y + 0.5).distance_to(center)
				var alpha = clampf(radius + 1.0 - dist, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, alpha))
		_circle_texture = ImageTexture.create_from_image(img)
	return _circle_texture

func _process(delta: float) -> void:
	if visuals_map.is_empty():
		return
		
	var needs_redraw = false
	
	# Check camera changes for dirty redraw
	if is_instance_valid(camera):
		if camera.position != _last_camera_pos or camera.zoom.x != _last_camera_zoom:
			_last_camera_pos = camera.position
			_last_camera_zoom = camera.zoom.x
			needs_redraw = true
			
	# Process timers only on flashing visuals
	for vis in visuals_map.values():
		if is_instance_valid(vis) and vis.is_flashing:
			if vis._process_port_flashes(delta):
				needs_redraw = true
				
	if needs_redraw:
		queue_redraw()

func _draw() -> void:
	if visuals_map.is_empty():
		return
		
	var font = _fallback_font
	if font == null:
		font = ThemeDB.fallback_font
		
	var view_rect = camera.get_visible_world_rect(128.0) if is_instance_valid(camera) else Rect2(-99999, -99999, 199998, 199998)
	var current_zoom = camera.zoom.x if is_instance_valid(camera) else 1.0
	var is_low_lod = (current_zoom < 0.45)
	
	# Collect visible building visuals (Frustum Culling)
	var visible_visuals: Array[BuildingVisual] = []
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
			visible_visuals.append(vis)
			
	if is_instance_valid(hud) and hud.has_method("update_culling_stats"):
		hud.update_culling_stats(visible_visuals.size(), visuals_map.size())
		
	if visible_visuals.is_empty():
		return

	# Categorize into standard buildings and splitters
	var std_visuals: Array[BuildingVisual] = []
	var splitter_visuals: Array[BuildingVisual] = []
	
	for vis in visible_visuals:
		if vis.data.is_splitter:
			splitter_visuals.append(vis)
		else:
			std_visuals.append(vis)

	var circle_tex = _get_circle_texture()
	var outer_size = Vector2(11, 11)
	var outer_offset = Vector2(5.5, 5.5)
	var inner_size = Vector2(8, 8)
	var inner_offset = Vector2(4, 4)
	var out_color = Color(1.0, 0.85, 0.2, 0.9)
	var in_color = Color(0.3, 0.7, 1.0, 0.9)

	# =========================================================================
	# LAYER 1: Ports of Standard Buildings (drawn BEFORE building backgrounds/borders)
	# =========================================================================
	# 1A: Outer Black Circles for Standard Buildings
	for vis in std_visuals:
		for pt in vis._cached_out_ports_local:
			var pos = vis.global_position + pt
			draw_texture_rect(circle_tex, Rect2(pos - outer_offset, outer_size), false, Color.BLACK)
		for pt in vis._cached_in_ports_local:
			var pos = vis.global_position + pt
			draw_texture_rect(circle_tex, Rect2(pos - outer_offset, outer_size), false, Color.BLACK)
			
	# 1B: Inner Colored Circles for Standard Buildings
	for vis in std_visuals:
		for pt in vis._cached_out_ports_local:
			var pos = vis.global_position + pt
			draw_texture_rect(circle_tex, Rect2(pos - inner_offset, inner_size), false, out_color)
		for pt in vis._cached_in_ports_local:
			var pos = vis.global_position + pt
			draw_texture_rect(circle_tex, Rect2(pos - inner_offset, inner_size), false, in_color)

	# =========================================================================
	# LAYER 2: Building Background Panels (ALL buildings)
	# =========================================================================
	var bg_color = Color(0.08, 0.1, 0.12, 0.95)
	for vis in visible_visuals:
		var size_px = Vector2(vis.data.size_in_cells * vis.cell_size)
		var top_left = vis.global_position - size_px / 2.0
		draw_rect(Rect2(top_left, size_px), bg_color, true)

	# =========================================================================
	# LAYER 3: Building Borders / Outlines (Batched into 1 draw_multiline per color)
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
	# LAYER 4: Progress Bars (Standard Buildings)
	# =========================================================================
	if not is_low_lod:
		# 4A: Progress Bar Backgrounds
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
				
		# 4B: Progress Bar Fills
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
	# LAYER 5: Internal Lines on Splitters (drawn OVER building panels)
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
	# LAYER 6: Ports on Splitters (drawn OVER splitter lines)
	# =========================================================================
	# 6A: Outer Black Circles for Splitters
	for vis in splitter_visuals:
		for pt in vis._cached_out_ports_local:
			var pos = vis.global_position + pt
			draw_texture_rect(circle_tex, Rect2(pos - outer_offset, outer_size), false, Color.BLACK)
		for pt in vis._cached_in_ports_local:
			var pos = vis.global_position + pt
			draw_texture_rect(circle_tex, Rect2(pos - outer_offset, outer_size), false, Color.BLACK)
			
	# 6B: Inner Colored Circles for Splitters
	for vis in splitter_visuals:
		for pt in vis._cached_out_ports_local:
			var pos = vis.global_position + pt
			draw_texture_rect(circle_tex, Rect2(pos - inner_offset, inner_size), false, out_color)
		for pt in vis._cached_in_ports_local:
			var pos = vis.global_position + pt
			draw_texture_rect(circle_tex, Rect2(pos - inner_offset, inner_size), false, in_color)

	# =========================================================================
	# LAYER 7: Text (Titles & Resource Lists using pre-cached text strings)
	# =========================================================================
	if not is_low_lod and font != null:
		# 7A: Title Outlines
		for vis in std_visuals:
			var size_px = Vector2(vis.data.size_in_cells * vis.cell_size)
			var top_left = vis.global_position - size_px / 2.0
			var title_str = vis._cached_title_str
			var title_pos = Vector2(top_left.x, top_left.y + 14.0)
			draw_string_outline(font, title_pos, title_str, HORIZONTAL_ALIGNMENT_CENTER, size_px.x, 11, 2, Color.BLACK)
			
		# 7B: Title Text Fills
		for vis in std_visuals:
			var size_px = Vector2(vis.data.size_in_cells * vis.cell_size)
			var top_left = vis.global_position - size_px / 2.0
			var title_str = vis._cached_title_str
			var title_pos = Vector2(top_left.x, top_left.y + 14.0)
			draw_string(font, title_pos, title_str, HORIZONTAL_ALIGNMENT_CENTER, size_px.x, 11, vis.accent_color)
			
		# 7C: Resource Text Outlines
		for vis in std_visuals:
			var size_px = Vector2(vis.data.size_in_cells * vis.cell_size)
			var top_left = vis.global_position - size_px / 2.0
			_draw_resource_text_pass(vis, font, top_left, size_px, true)

		# 7D: Resource Text Fills
		for vis in std_visuals:
			var size_px = Vector2(vis.data.size_in_cells * vis.cell_size)
			var top_left = vis.global_position - size_px / 2.0
			_draw_resource_text_pass(vis, font, top_left, size_px, false)

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
