extends Node2D
class_name InputController

## Component dedicated to handling mouse click/drag actions on the factory grid.

signal building_clicked(building_id: int)
signal building_right_clicked(building_id: int)
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

func _process(_delta: float) -> void:
	if network == null:
		return
		
	# Process building preview positioning in BUILD mode
	if current_mode == 1: # MouseMode.BUILD
		var grid_pos = _get_grid_position_under_mouse()
		build_preview.global_position = Vector2(grid_pos) * cell_size + Vector2(cell_size/2.0 - 55, cell_size/2.0 - 45)
		
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
			var start_pt = source_vis.global_position
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
								empty_space_clicked.emit(grid_pos)
							else:
								building_clicked.emit(building_id)
						elif current_mode == 3: # MouseMode.DEMOLISH
							building_clicked.emit(building_id)
						else:
							# Inspect mode (0)
							building_clicked.emit(building_id)
							
				elif _is_dragging_building:
					if _has_dragged:
						building_move_completed.emit()
					else:
						# Short click - treat as click action
						if current_mode == 3: # MouseMode.DEMOLISH
							building_clicked.emit(_dragged_building_id)
						else:
							building_clicked.emit(_dragged_building_id)
							
					_is_dragging_building = false
					_dragged_building_id = 0
					
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				if building_id != 0:
					# RMB on building starts linking
					building_right_clicked.emit(building_id)
				else:
					# RMB on empty space cancels current mode
					if current_mode != 0:
						link_mode_cancelled.emit()
						get_viewport().set_input_as_handled()
						
	elif event is InputEventMouseMotion:
		if _is_dragging_building:
			if get_global_mouse_position().distance_to(_lmb_press_pos) > 8:
				_has_dragged = true
				
			var hover_grid_pos = _get_grid_position_under_mouse()
			var b_data = network.buildings.get(_dragged_building_id)
			if b_data and hover_grid_pos != b_data.grid_position:
				if not network.grid.has(hover_grid_pos):
					network.grid.erase(b_data.grid_position)
					network.grid[hover_grid_pos] = _dragged_building_id
					b_data.grid_position = hover_grid_pos
					
					network.rebuild_caches()
					
					var visual = visuals_map.get(_dragged_building_id)
					if is_instance_valid(visual):
						visual.position = Vector2(hover_grid_pos) * cell_size + Vector2(cell_size / 2.0, cell_size / 2.0)
					
		elif is_instance_valid(camera) and camera.is_panning:
			if get_global_mouse_position().distance_to(_lmb_press_pos) > 8:
				_has_dragged = true

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
		floori(m_pos.x / cell_size),
		floori(m_pos.y / cell_size)
	)
