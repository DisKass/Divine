extends Node2D
class_name InputController

## Component dedicated to handling mouse click/drag actions on the factory grid.

signal building_clicked(building_id: int)
signal building_right_clicked(building_id: int, port_index: int)
signal empty_space_clicked(grid_pos: Vector2i)
signal building_move_completed
signal link_mode_cancelled
signal selection_changed(selected_ids: Array[int])
signal demolish_requested(selected_ids: Array[int])
signal copy_requested(selected_ids: Array[int])
signal copy_placement_confirmed(target_origin: Vector2i)
signal copy_placement_cancelled

# Config references
var cell_size: int = 64
var camera: GameCamera
var network: FactoryNetwork
var visuals_map: Dictionary = {}
var build_preview: PanelContainer
var building_renderer: BuildingRenderer
var connection_renderer: ConnectionRenderer

# State mirrored from MainGame
var current_mode: int = 0 # 0 = INSPECT, 1 = BUILD, 2 = LINK, 3 = DEMOLISH, 4 = COPY_BUILD
var selected_build_type: String = ""
var link_source_id: int = 0
var link_source_port: int = 0

# Multi-selection state
var selected_building_ids: Array[int] = []

# Box Selection internal state
var _is_box_selecting: bool = false
var _is_additive_box_select: bool = false
var _initial_selected_ids: Array[int] = []
var _box_select_start: Vector2 = Vector2.ZERO
var _box_select_current: Vector2 = Vector2.ZERO

# Drag & Panning internal state
var _is_dragging_building: bool = false
var _dragged_building_id: int = 0
var _drag_building_start_grid: Vector2i
var _is_dragging_group: bool = false
var _drag_group_starts: Dictionary = {} # building_id -> Vector2i start grid pos
var _lmb_press_pos: Vector2
var _lmb_press_screen_pos: Vector2
var _has_dragged: bool = false

# Stream Building state (Shift + LMB drag in BUILD mode)
var _is_stream_building: bool = false
var _last_stream_build_grid: Vector2i = Vector2i(-99999, -99999)

# Copy preview state (mirrored from MainGame)
var copy_preview_info: Dictionary = {} # { "buildings": Array, "origin_grid": Vector2i, "is_valid": bool }

func setup(p_camera: GameCamera, p_network: FactoryNetwork, p_visuals_map: Dictionary, p_preview: PanelContainer, p_building_renderer: BuildingRenderer = null, p_connection_renderer: ConnectionRenderer = null) -> void:
	camera = p_camera
	network = p_network
	visuals_map = p_visuals_map
	build_preview = p_preview
	building_renderer = p_building_renderer
	connection_renderer = p_connection_renderer
	
	_is_dragging_building = false
	_dragged_building_id = 0
	_is_dragging_group = false
	_drag_group_starts.clear()
	_is_box_selecting = false
	_is_additive_box_select = false
	_initial_selected_ids.clear()
	_is_stream_building = false
	link_source_id = 0
	link_source_port = 0
	selected_building_ids.clear()

func _request_renderers_redraw() -> void:
	if is_instance_valid(building_renderer):
		building_renderer.mark_culling_dirty()
		building_renderer.request_static_redraw()
	if is_instance_valid(connection_renderer) and connection_renderer.has_method("mark_lines_dirty"):
		connection_renderer.mark_lines_dirty()

func set_selected_buildings(ids: Array[int]) -> void:
	selected_building_ids.clear()
	selected_building_ids.append_array(ids)
	for b_id in visuals_map:
		var visual = visuals_map[b_id]
		if is_instance_valid(visual):
			visual.is_selected = (b_id in selected_building_ids)
	if is_instance_valid(building_renderer):
		building_renderer.mark_borders_dirty()

var _last_hovered_id: int = 0

func _process(_delta: float) -> void:
	if network == null:
		return
		
	# Process building preview positioning in BUILD mode (centered under mouse cursor)
	if current_mode == 1 and is_instance_valid(build_preview): # MouseMode.BUILD
		var grid_pos = _get_build_placement_grid_pos(selected_build_type)
		var b_size = BuildingData.get_default_size(selected_build_type)
		var target_size_px = Vector2(b_size * cell_size)
		build_preview.custom_minimum_size = target_size_px
		build_preview.size = target_size_px
		build_preview.global_position = Vector2(grid_pos) * cell_size
		
	# Update hovered building state only when hover target changes
	var hover_building_id = _get_building_id_under_mouse()
	if _is_dragging_building or _is_dragging_group:
		hover_building_id = 0
		
	if hover_building_id != _last_hovered_id:
		if _last_hovered_id != 0:
			var prev_vis = visuals_map.get(_last_hovered_id)
			if is_instance_valid(prev_vis):
				prev_vis.is_hovered = false
		if hover_building_id != 0:
			var new_vis = visuals_map.get(hover_building_id)
			if is_instance_valid(new_vis):
				new_vis.is_hovered = true
		_last_hovered_id = hover_building_id
		if is_instance_valid(building_renderer):
			building_renderer.mark_borders_dirty()
				
	# Request redraw for temporary link line, box selection, or copy preview
	queue_redraw()

func _draw() -> void:
	# Draw temporary connection line if linking
	if current_mode == 2 and link_source_id != 0: # MouseMode.LINK
		var source_vis = visuals_map.get(link_source_id)
		if is_instance_valid(source_vis):
			var start_pt = source_vis.get_port_global_position(true, link_source_port) if source_vis.has_method("get_port_global_position") else source_vis.global_position
			var end_pt = get_global_mouse_position()
			draw_line(start_pt, end_pt, Color(1.0, 0.9, 0.3, 0.8), 2.0)

	# Draw Box Selection rectangle
	if _is_box_selecting:
		var top_left = Vector2(minf(_box_select_start.x, _box_select_current.x), minf(_box_select_start.y, _box_select_current.y))
		var size = Vector2(absf(_box_select_current.x - _box_select_start.x), absf(_box_select_current.y - _box_select_start.y))
		var rect = Rect2(top_left, size)
		draw_rect(rect, Color(0.2, 0.65, 1.0, 0.18), true) # Semi-transparent fill
		draw_rect(rect, Color(0.3, 0.8, 1.0, 0.95), false, 2.0) # Bright outline

	# Draw Copy Placement preview (MouseMode.COPY_BUILD) matching standard build preview visual (StyleBoxFlat with rounded corners)
	if current_mode == 4 and not copy_preview_info.is_empty():
		var b_list = copy_preview_info.get("buildings", [])
		var origin_grid = copy_preview_info.get("origin_grid", Vector2i.ZERO)
		var is_valid = copy_preview_info.get("is_valid", false)
		
		var fill_col = Color(0.2, 0.85, 0.4, 0.15) if is_valid else Color(0.9, 0.25, 0.25, 0.15)
		var border_col = Color(0.2, 0.85, 0.4, 0.8) if is_valid else Color(0.9, 0.25, 0.25, 0.8)
		
		var style = StyleBoxFlat.new()
		style.bg_color = fill_col
		style.border_color = border_col
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		
		for b in b_list:
			var rel_pos: Vector2i = b.get("relative_pos", Vector2i.ZERO)
			var b_size: Vector2i = b.get("size", Vector2i(1, 1))
			var cell_pos = origin_grid + rel_pos
			var rect = Rect2(Vector2(cell_pos) * cell_size, Vector2(b_size) * cell_size)
			style.draw(get_canvas_item(), rect)

func _unhandled_input(event: InputEvent) -> void:
	if network == null:
		return
		
	# Keyboard shortcuts (Delete = demolish, Ctrl+C = copy)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_DELETE:
			if selected_building_ids.size() > 0:
				demolish_requested.emit(selected_building_ids)
				get_viewport().set_input_as_handled()
				return
		elif event.keycode == KEY_C and (event.ctrl_pressed or event.command_or_control_autorepeat):
			if selected_building_ids.size() > 0:
				copy_requested.emit(selected_building_ids)
				get_viewport().set_input_as_handled()
				return
		
	if event is InputEventMouseButton:
		var building_id = _get_building_id_under_mouse()
		var grid_pos = _get_grid_position_under_mouse()
		if building_id != 0 and network.buildings.has(building_id):
			grid_pos = network.buildings[building_id].grid_position
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_lmb_press_pos = get_global_mouse_position()
				_lmb_press_screen_pos = event.position
				_has_dragged = false
				
				# COPY_BUILD mode: LMB confirms copy placement
				if current_mode == 4: # MouseMode.COPY_BUILD
					var origin_grid = _get_copy_placement_origin_grid()
					copy_placement_confirmed.emit(origin_grid)
					get_viewport().set_input_as_handled()
					return
					
				# Check Ctrl + LMB (or Ctrl + Shift + LMB) box selection start (only in INSPECT mode)
				if current_mode == 0 and event.ctrl_pressed:
					_is_box_selecting = true
					_is_additive_box_select = event.shift_pressed
					_initial_selected_ids.clear()
					if _is_additive_box_select:
						_initial_selected_ids.append_array(selected_building_ids)
					_box_select_start = get_global_mouse_position()
					_box_select_current = _box_select_start
					get_viewport().set_input_as_handled()
					return
					
				# Check drag building / group: only if we clicked a building and we are in Inspect or Build mode
				if building_id != 0 and (current_mode == 0 or current_mode == 1):
					if selected_building_ids.size() > 1 and (building_id in selected_building_ids):
						# Multi-drag group
						_is_dragging_group = true
						_drag_group_starts.clear()
						for id in selected_building_ids:
							if network.buildings.has(id):
								_drag_group_starts[id] = network.buildings[id].grid_position
					else:
						# Single building drag
						_is_dragging_building = true
						_dragged_building_id = building_id
						_drag_building_start_grid = grid_pos
				else:
					if current_mode == 1: # MouseMode.BUILD
						_is_stream_building = true
						_last_stream_build_grid = _get_build_placement_grid_pos(selected_build_type)
						empty_space_clicked.emit(_last_stream_build_grid)
						get_viewport().set_input_as_handled()
						return
					else:
						if is_instance_valid(camera):
							camera.is_panning = true
			else:
				# Left mouse button released
				_is_stream_building = false
				
				if _is_box_selecting:
					_is_box_selecting = false
					_box_select_current = get_global_mouse_position()
					_finish_box_selection()
					get_viewport().set_input_as_handled()
					return
					
				if is_instance_valid(camera) and camera.is_panning:
					camera.is_panning = false
					if not _has_dragged:
						var sel_single: Array[int] = [building_id]
						var sel_empty: Array[int] = []
						if current_mode == 2: # MouseMode.LINK
							if building_id != 0:
								building_clicked.emit(building_id)
							else:
								link_mode_cancelled.emit()
						elif current_mode == 3: # MouseMode.DEMOLISH
							building_clicked.emit(building_id)
						else:
							# Inspect mode (0) - pure click on empty space or building without Ctrl
							if building_id != 0:
								set_selected_buildings(sel_single)
								selection_changed.emit(selected_building_ids)
								building_clicked.emit(building_id)
							else:
								set_selected_buildings(sel_empty)
								selection_changed.emit(selected_building_ids)
								building_clicked.emit(0)
							
				elif _is_dragging_group:
					if _has_dragged:
						var delta_grid = _get_group_drag_delta_grid()
						var is_valid = _check_group_drag_validity(delta_grid)
						if is_valid:
							for id in selected_building_ids:
								var new_pos = _drag_group_starts[id] + delta_grid
								network.move_building(id, new_pos)
								var visual = visuals_map.get(id)
								var b_data = network.buildings.get(id)
								if is_instance_valid(visual) and b_data:
									visual.is_invalid_drag = false
									var size_px = Vector2(b_data.size_in_cells * cell_size)
									visual.position = Vector2(b_data.grid_position) * cell_size + size_px / 2.0
							building_move_completed.emit()
						else:
							# Restore visual positions on invalid placement
							for id in selected_building_ids:
								var visual = visuals_map.get(id)
								var b_data = network.buildings.get(id)
								if is_instance_valid(visual) and b_data:
									visual.is_invalid_drag = false
									var size_px = Vector2(b_data.size_in_cells * cell_size)
									visual.position = Vector2(b_data.grid_position) * cell_size + size_px / 2.0
					else:
						# Short click on member of selected group
						var sel_single: Array[int] = [building_id]
						set_selected_buildings(sel_single)
						selection_changed.emit(selected_building_ids)
						building_clicked.emit(building_id)
						
					_is_dragging_group = false
					_drag_group_starts.clear()
					_request_renderers_redraw()
					
				elif _is_dragging_building:
					var visual = visuals_map.get(_dragged_building_id)
					var b_data = network.buildings.get(_dragged_building_id)
					if _has_dragged:
						var target_top_left = _get_dragged_target_top_left()
						var moved = network.move_building(_dragged_building_id, target_top_left)
						if is_instance_valid(visual) and b_data:
							visual.is_invalid_drag = false
							var size_px = Vector2(b_data.size_in_cells * cell_size)
							visual.position = Vector2(b_data.grid_position) * cell_size + size_px / 2.0
						if moved:
							building_move_completed.emit()
					else:
						# Short click - single building click
						if is_instance_valid(visual):
							visual.is_invalid_drag = false
						if current_mode == 3: # MouseMode.DEMOLISH
							building_clicked.emit(_dragged_building_id)
						else:
							var sel_single: Array[int] = [_dragged_building_id]
							set_selected_buildings(sel_single)
							selection_changed.emit(selected_building_ids)
							building_clicked.emit(_dragged_building_id)
							
					_is_dragging_building = false
					_dragged_building_id = 0
					_request_renderers_redraw()
					
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				if current_mode == 4: # MouseMode.COPY_BUILD
					copy_placement_cancelled.emit()
					get_viewport().set_input_as_handled()
					return
					
				if building_id != 0:
					# RMB on building starts linking from specific sub-port
					var visual = visuals_map.get(building_id)
					var port_idx = 0
					if is_instance_valid(visual) and visual.has_method("get_output_port_at_position"):
						port_idx = visual.get_output_port_at_position(get_global_mouse_position())
					building_right_clicked.emit(building_id, port_idx)
				else:
					# RMB on empty space cancels current mode
					if current_mode != 0:
						link_mode_cancelled.emit()
						get_viewport().set_input_as_handled()
						
	elif event is InputEventMouseMotion:
		if event.position.distance_to(_lmb_press_screen_pos) > 8.0:
			_has_dragged = true

		if _is_box_selecting:
			_box_select_current = get_global_mouse_position()
			_update_box_selection_realtime()
			queue_redraw()
			
		elif current_mode == 4: # MouseMode.COPY_BUILD
			queue_redraw()
			
		elif _is_stream_building and current_mode == 1 and Input.is_key_pressed(KEY_SHIFT):
			var build_pos = _get_build_placement_grid_pos(selected_build_type)
			if build_pos != _last_stream_build_grid:
				_last_stream_build_grid = build_pos
				empty_space_clicked.emit(build_pos)
				
		elif _is_dragging_group:
			var delta_grid = _get_group_drag_delta_grid()
			var is_valid = _check_group_drag_validity(delta_grid)
			
			for id in selected_building_ids:
				var orig_grid = _drag_group_starts.get(id, Vector2i.ZERO)
				var target_top_left = orig_grid + delta_grid
				var b_data = network.buildings.get(id)
				var visual = visuals_map.get(id)
				if b_data and is_instance_valid(visual):
					var size_px = Vector2(b_data.size_in_cells * cell_size)
					visual.position = Vector2(target_top_left) * cell_size + size_px / 2.0
					visual.is_invalid_drag = not is_valid
			_request_renderers_redraw()

		elif _is_dragging_building:
			var target_top_left = _get_dragged_target_top_left()
			var b_data = network.buildings.get(_dragged_building_id)
			var visual = visuals_map.get(_dragged_building_id)
			if b_data and is_instance_valid(visual):
				var size_px = Vector2(b_data.size_in_cells * cell_size)
				visual.position = Vector2(target_top_left) * cell_size + size_px / 2.0
				var is_free = network.is_area_free(target_top_left, b_data.size_in_cells, _dragged_building_id)
				visual.is_invalid_drag = not is_free
			_request_renderers_redraw()

func _update_box_selection_realtime() -> void:
	var start_pos = _box_select_start
	var end_pos = _box_select_current
	if start_pos.distance_to(end_pos) < 8.0:
		return
		
	var top_left = Vector2(minf(start_pos.x, end_pos.x), minf(start_pos.y, end_pos.y))
	var size = Vector2(absf(end_pos.x - start_pos.x), absf(end_pos.y - start_pos.y))
	var sel_rect = Rect2(top_left, size)
	
	var enclosed_ids: Array[int] = []
	for b_id in visuals_map:
		var visual = visuals_map[b_id]
		if is_instance_valid(visual) and visual.data != null:
			var size_px = Vector2(visual.data.size_in_cells * cell_size)
			var b_top_left = visual.global_position - size_px / 2.0
			var b_rect = Rect2(b_top_left, size_px)
			if sel_rect.intersects(b_rect):
				enclosed_ids.append(b_id)
				
	if _is_additive_box_select:
		var combined: Array[int] = []
		combined.append_array(_initial_selected_ids)
		for id in enclosed_ids:
			if not (id in combined):
				combined.append(id)
		set_selected_buildings(combined)
	else:
		set_selected_buildings(enclosed_ids)
		
	selection_changed.emit(selected_building_ids)

func _finish_box_selection() -> void:
	var start_pos = _box_select_start
	var end_pos = _box_select_current
	var dist = start_pos.distance_to(end_pos)
	
	if dist < 8.0:
		# Short click with Ctrl -> toggle/select building under mouse
		var b_id = _get_building_id_under_mouse()
		if b_id != 0:
			var new_arr: Array[int] = []
			new_arr.append_array(selected_building_ids)
			if b_id in new_arr:
				new_arr.erase(b_id)
			else:
				new_arr.append(b_id)
			set_selected_buildings(new_arr)
		else:
			if not _is_additive_box_select:
				var empty_arr: Array[int] = []
				set_selected_buildings(empty_arr)
		selection_changed.emit(selected_building_ids)
	else:
		_update_box_selection_realtime()

func _get_group_drag_delta_grid() -> Vector2i:
	var delta_world = get_global_mouse_position() - _lmb_press_pos
	return Vector2i(
		roundi(delta_world.x / cell_size),
		roundi(delta_world.y / cell_size)
	)

func _check_group_drag_validity(delta_grid: Vector2i) -> bool:
	for id in selected_building_ids:
		var orig_pos = _drag_group_starts.get(id, Vector2i.ZERO)
		var target_pos = orig_pos + delta_grid
		var b_data = network.buildings.get(id)
		if b_data == null:
			return false
		for x in range(b_data.size_in_cells.x):
			for y in range(b_data.size_in_cells.y):
				var cell = target_pos + Vector2i(x, y)
				if network.grid.has(cell):
					var occ_id = network.grid[cell]
					if not (occ_id in selected_building_ids):
						return false
	return true

func _get_building_id_under_mouse() -> int:
	var m_pos = get_global_mouse_position()
	var grid_pos = Vector2i(
		floori(m_pos.x / cell_size),
		floori(m_pos.y / cell_size)
	)
	if network != null and network.grid.has(grid_pos):
		return network.grid[grid_pos]
	return 0

func _get_grid_position_under_mouse() -> Vector2i:
	var m_pos = get_global_mouse_position()
	return Vector2i(
		floori(m_pos.x / cell_size),
		floori(m_pos.y / cell_size)
	)

## Calculates top-left grid cell for build preview so that cursor stays at center of building.
func _get_build_placement_grid_pos(b_type: String) -> Vector2i:
	var m_pos = get_global_mouse_position()
	var b_size = BuildingData.get_default_size(b_type)
	var size_px = Vector2(b_size * cell_size)
	var top_left_world = m_pos - size_px / 2.0
	return Vector2i(
		floori((top_left_world.x + cell_size / 2.0) / cell_size),
		floori((top_left_world.y + cell_size / 2.0) / cell_size)
	)

func _get_copy_placement_origin_grid() -> Vector2i:
	var m_pos = get_global_mouse_position()
	var bounds_size: Vector2i = copy_preview_info.get("bounds_size", Vector2i(1, 1))
	var size_px = Vector2(bounds_size * cell_size)
	var top_left_world = m_pos - size_px / 2.0
	return Vector2i(
		floori((top_left_world.x + cell_size / 2.0) / cell_size),
		floori((top_left_world.y + cell_size / 2.0) / cell_size)
	)

## Calculates target top-left grid position based on relative mouse delta from click position (threshold at 0.5 cell displacement).
func _get_dragged_target_top_left() -> Vector2i:
	var delta_world = get_global_mouse_position() - _lmb_press_pos
	var delta_grid = Vector2i(
		roundi(delta_world.x / cell_size),
		roundi(delta_world.y / cell_size)
	)
	return _drag_building_start_grid + delta_grid
