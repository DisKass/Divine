extends Node2D
class_name ConnectionRenderer

## High-performance batched renderer for factory connection pipes.
## Resource transfers instantly highlight connection lines with resource-colored flashes (0.15s pulse), eliminating packet lerping overhead.

@export var line_color: Color = Color(0.2, 0.6, 0.9, 0.6) # Sleek transparent blue
@export var line_width: float = 3.0

var state: GameState
var visuals_map: Dictionary = {}
var camera: GameCamera

# Active connection flashes: "from_id:from_port_to_id:to_port" -> Dictionary
var active_flashes: Dictionary = {}

func setup(p_state: GameState, p_visuals_map: Dictionary, p_camera: GameCamera = null) -> void:
	z_as_relative = false
	z_index = 1 # Render connection pipes completely behind building ports (2) and panels (3)
	if is_instance_valid(state) and state.factory.resource_transferred.is_connected(_on_resource_transferred):
		state.factory.resource_transferred.disconnect(_on_resource_transferred)
		
	state = p_state
	visuals_map = p_visuals_map
	camera = p_camera
	active_flashes.clear()
	_last_conn_count = -1
	_lines_dirty = true
	_cached_pipe_lines.clear()
	queue_redraw()
	
	if state != null:
		state.factory.resource_transferred.connect(_on_resource_transferred)

func _on_resource_transferred(from_id: int, from_port: int, to_id: int, to_port: int, resource_name: String, _amount: float, _transfer_rate: float) -> void:
	var from_vis: BuildingVisual = visuals_map.get(from_id)
	var to_vis: BuildingVisual = visuals_map.get(to_id)
	
	if not is_instance_valid(from_vis) or not is_instance_valid(to_vis):
		return
		
	# Skip flash if both source and target buildings are off-screen
	if not from_vis.visible and not to_vis.visible:
		return
		
	# Trigger output port pulse on source visual
	from_vis.trigger_output_pulse(from_port)
		
	var flash_key = [from_id, from_port, to_id, to_port]
	active_flashes[flash_key] = {
		"timer": 0.35,
		"color": _get_resource_color(resource_name),
		"from_id": from_id,
		"from_port": from_port,
		"to_id": to_id,
		"to_port": to_port
	}
	queue_redraw()

var _last_camera_pos: Vector2 = Vector2.INF
var _last_camera_zoom: float = -1.0
var _cached_pipe_lines: PackedVector2Array = PackedVector2Array()
var _lines_dirty: bool = true
var _last_conn_count: int = -1

func mark_lines_dirty() -> void:
	_lines_dirty = true
	queue_redraw()

func _process(delta: float) -> void:
	if state == null or visuals_map.is_empty():
		return
		
	var needs_redraw = false
	
	if is_instance_valid(camera):
		if camera.position != _last_camera_pos or camera.zoom.x != _last_camera_zoom:
			_last_camera_pos = camera.position
			_last_camera_zoom = camera.zoom.x
			needs_redraw = true
			
	if state.factory.connections.size() != _last_conn_count:
		_last_conn_count = state.factory.connections.size()
		_lines_dirty = true
		needs_redraw = true
			
	if not active_flashes.is_empty():
		var keys_to_remove: Array = []
		for key in active_flashes:
			var flash = active_flashes[key]
			flash["timer"] -= delta
			if flash["timer"] <= 0.0:
				keys_to_remove.append(key)
				
		for key in keys_to_remove:
			active_flashes.erase(key)
			
		needs_redraw = true
		
	if needs_redraw:
		queue_redraw()

func _draw() -> void:
	if state == null or visuals_map.is_empty():
		return
		
	var view_rect = camera.get_visible_world_rect(128.0) if is_instance_valid(camera) else Rect2(-99999, -99999, 199998, 199998)

	if _lines_dirty:
		_lines_dirty = false
		_cached_pipe_lines.clear()
		for conn in state.factory.connections:
			var from_id = conn["from_id"]
			var from_port = int(conn.get("from_port", 0))
			var to_id = conn["to_id"]
			var to_port = int(conn.get("to_port", 0))
			
			var from_vis: BuildingVisual = visuals_map.get(from_id)
			var to_vis: BuildingVisual = visuals_map.get(to_id)
			
			if not is_instance_valid(from_vis) or not is_instance_valid(to_vis):
				continue
				
			var start_pt = from_vis.get_port_global_position(true, from_port)
			var end_pt = to_vis.get_port_global_position(false, to_port)
			
			_cached_pipe_lines.append(start_pt)
			_cached_pipe_lines.append(end_pt)
			
	if _cached_pipe_lines.size() > 0:
		draw_multiline(_cached_pipe_lines, line_color, line_width)

	# 2. Draw instant connection flash highlights for active resource transfers (0.35s pulse timing)
	for key in active_flashes:
		var flash = active_flashes[key]
		var from_vis: BuildingVisual = visuals_map.get(flash["from_id"])
		var to_vis: BuildingVisual = visuals_map.get(flash["to_id"])
		if not is_instance_valid(from_vis) or not is_instance_valid(to_vis):
			continue
			
		var start_pt = from_vis.get_port_global_position(true, flash["from_port"])
		var end_pt = to_vis.get_port_global_position(false, flash["to_port"])
		
		var alpha = minf(1.0, flash["timer"] / 0.15)
		var res_color: Color = flash["color"]
		var glow_color = Color(res_color.r, res_color.g, res_color.b, alpha * 0.85)
		var core_color = Color(1.0, 1.0, 1.0, alpha)
		
		# Outer glow line
		draw_line(start_pt, end_pt, glow_color, line_width + 3.0)
		# Inner core line
		draw_line(start_pt, end_pt, core_color, line_width)

func _get_resource_color(res_name: String) -> Color:
	match res_name:
		"credits":
			return Color(1.0, 0.9, 0.2) # Gold
		"iron_ore":
			return Color(0.9, 0.55, 0.3) # Amber / Ore
		"iron_plate":
			return Color(0.7, 0.85, 1.0) # Silver Steel
		"iron_gear":
			return Color(0.9, 0.7, 0.4) # Bronze Gear
		"coal":
			return Color(0.4, 0.4, 0.45) # Dark Coal
		"mana_crystal":
			return Color(0.8, 0.4, 1.0) # Mana Purple
		"crystal_dust":
			return Color(0.9, 0.7, 1.0) # Dust Light Purple
		"mana_essence":
			return Color(0.2, 0.9, 0.9) # Essence Cyan
		"runesteel_ingot", "steel_ingot":
			return Color(0.5, 0.8, 0.9) # Steel Ingot Blue-Gray
		_:
			return Color(0.4, 0.85, 1.0) # Glowing Cyan
