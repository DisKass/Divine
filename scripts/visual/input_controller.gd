extends Node2D
class_name InputController

## Component dedicated to handling mouse click/drag actions on the factory grid.

signal building_clicked(building_id: int)
signal building_right_clicked(building_id: int, port_index: int)
signal empty_space_clicked(grid_pos: Vector2i)
signal building_move_completed
signal link_mode_cancelled

# Config references
var cell_size: int = 64
var camera: GameCamera
var network: FactoryNetwork
var visuals_map: Dictionary = {}
var build_preview: PanelContainer

# State mirrored from MainGame
var current_mode: int = 0 # 0 = INSPECT, 1 = BUILD, 2 = LINK, 3 = DEMOLISH
var selected_build_type: String = ""
var link_source_id: int = 0
var link_source_port: int = 0

# Drag & Panning internal state
var _is_dragging_building: bool = false
var _dragged_building_id: int = 0
var _drag_building_start_grid: Vector2i
var _lmb_press_pos: Vector2
var _has_dragged: bool = false

func setup(p_camera: GameCamera, p_network: FactoryNetwork, p_visuals_map: Dictionary, p_preview: PanelContainer) -> void:
	camera = p_camera
	network = p_network
	visuals_map = p_visuals_map
	build_preview = p_preview
	
	_is_dragging_building = false
	_dragged_building_id = 0
	link_source_id = 0
	link_source_port = 0

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
		
	# Update hovered building state
	var hover_building_id = _get_building_id_under_mouse()
	for b_id in visuals_map:
		var visual = visuals_map[b_id]
		if is_instance_valid(visual):
			if _is_dragging_building and b_id == _dragged_building_id:
				visual.is_hovered = false
			else:
				visual.is_hovered = (b_id == hover_building_id)
				
	# Request redraw for temporary link line
	queue_redraw()

func _draw() -> void:
	# Draw temporary connection line if linking
	if current_mode == 2 and link_source_id != 0: # MouseMode.LINK
		var source_vis = visuals_map.get(link_source_id)
		if is_instance_valid(source_vis):
			var start_pt = source_vis.get_port_global_position(true, link_source_port) if source_vis.has_method("get_port_global_position") else source_vis.global_position
			var end_pt = get_global_mouse_position()
			draw_line(start_pt, end_pt, Color(1.0, 0.9, 0.3, 0.8), 2.0)

func _unhandled_input(event: InputEvent) -> void:
	if network == null:
		return
		
	if event is InputEventMouseButton:
		var building_id = _get_building_id_under_mouse()
		var grid_pos = _get_grid_position_under_mouse()
		if building_id != 0 and network.buildings.has(building_id):
			grid_pos = network.buildings[building_id].grid_position
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_lmb_press_pos = get_global_mouse_position()
				_has_dragged = false
				
				# Drag building: only if we clicked a building and we are in Inspect or Build mode
				if building_id != 0 and (current_mode == 0 or current_mode == 1):
					_is_dragging_building = true
					_dragged_building_id = building_id
					_drag_building_start_grid = grid_pos
				else:
					if is_instance_valid(camera):
						camera.is_panning = true
			else:
				# Left mouse button released
				if is_instance_valid(camera) and camera.is_panning:
					camera.is_panning = false
					if not _has_dragged:
						if current_mode == 2: # MouseMode.LINK
							if building_id != 0:
								building_clicked.emit(building_id)
							else:
								link_mode_cancelled.emit()
						elif current_mode == 1: # MouseMode.BUILD
							if building_id == 0:
								var build_pos = _get_build_placement_grid_pos(selected_build_type)
								empty_space_clicked.emit(build_pos)
							else:
								building_clicked.emit(building_id)
						elif current_mode == 3: # MouseMode.DEMOLISH
							building_clicked.emit(building_id)
						else:
							# Inspect mode (0)
							building_clicked.emit(building_id)
							
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
						# Short click - treat as click action
						if is_instance_valid(visual):
							visual.is_invalid_drag = false
						if current_mode == 3: # MouseMode.DEMOLISH
							building_clicked.emit(_dragged_building_id)
						else:
							building_clicked.emit(_dragged_building_id)
							
					_is_dragging_building = false
					_dragged_building_id = 0
					
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
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
		if _is_dragging_building:
			if get_global_mouse_position().distance_to(_lmb_press_pos) > 8:
				_has_dragged = true
				
			var target_top_left = _get_dragged_target_top_left()
			var b_data = network.buildings.get(_dragged_building_id)
			var visual = visuals_map.get(_dragged_building_id)
			if b_data and is_instance_valid(visual):
				var size_px = Vector2(b_data.size_in_cells * cell_size)
				visual.position = Vector2(target_top_left) * cell_size + size_px / 2.0
				var is_free = network.is_area_free(target_top_left, b_data.size_in_cells, _dragged_building_id)
				visual.is_invalid_drag = not is_free
					
		elif is_instance_valid(camera) and camera.is_panning:
			if get_global_mouse_position().distance_to(_lmb_press_pos) > 8:
				_has_dragged = true

func _get_building_id_under_mouse() -> int:
	var m_pos = get_global_mouse_position()
	for b_id in visuals_map:
		var visual = visuals_map[b_id]
		if is_instance_valid(visual) and visual.data != null:
			var size_px = Vector2(visual.data.size_in_cells * cell_size)
			var top_left = visual.global_position - size_px / 2.0
			var rect = Rect2(top_left, size_px)
			if rect.has_point(m_pos):
				return b_id
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

## Calculates target top-left grid position based on relative mouse delta from click position (threshold at 0.5 cell displacement).
func _get_dragged_target_top_left() -> Vector2i:
	var delta_world = get_global_mouse_position() - _lmb_press_pos
	var delta_grid = Vector2i(
		roundi(delta_world.x / cell_size),
		roundi(delta_world.y / cell_size)
	)
	return _drag_building_start_grid + delta_grid
