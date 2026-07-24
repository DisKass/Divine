extends Node2D
class_name ConnectionRenderer

## High-performance batched renderer for factory connection pipes.
## Resource transfers instantly highlight connection lines with resource-colored flashes (0.15s pulse), eliminating packet lerping overhead.

@export var line_color: Color = Color(0.2, 0.6, 0.9, 0.6) # Sleek transparent blue
@export var line_width: float = 3.0

var network: FactoryNetwork
var visuals_map: Dictionary = {}
var camera: GameCamera

# Active connection flashes: "from_id:from_port_to_id:to_port" -> Dictionary
var active_flashes: Dictionary = {}

func setup(p_network: FactoryNetwork, p_visuals_map: Dictionary, p_camera: GameCamera = null) -> void:
	z_as_relative = false
	z_index = 1 # Render connection pipes completely behind building ports (2) and panels (3)
	if is_instance_valid(network) and network.resource_transferred.is_connected(_on_resource_transferred):
		network.resource_transferred.disconnect(_on_resource_transferred)
		
	network = p_network
	visuals_map = p_visuals_map
	camera = p_camera
	active_flashes.clear()
	
	if network != null:
		network.resource_transferred.connect(_on_resource_transferred)

func _on_resource_transferred(from_id: int, from_port: int, to_id: int, to_port: int, resource_name: String, _amount: float, _transfer_rate: float) -> void:
	var from_vis: BuildingVisual = visuals_map.get(from_id)
	var to_vis: BuildingVisual = visuals_map.get(to_id)
	
	if not is_instance_valid(from_vis) or not is_instance_valid(to_vis):
		return
		
	# Skip flash if both source and target buildings are off-screen
	if not from_vis.visible and not to_vis.visible:
		return
		
	# Trigger output port pulse on source visual
	if from_vis.has_method("trigger_output_pulse"):
		from_vis.trigger_output_pulse(from_port)
		
	var flash_key = "%d:%d_%d:%d" % [from_id, from_port, to_id, to_port]
	active_flashes[flash_key] = {
		"timer": 0.35,
		"color": _get_resource_color(resource_name),
		"from_id": from_id,
		"from_port": from_port,
		"to_id": to_id,
		"to_port": to_port
	}
	queue_redraw()

func _process(delta: float) -> void:
	if active_flashes.is_empty():
		return
		
	var keys_to_remove: Array = []
	for key in active_flashes:
		var flash = active_flashes[key]
		flash["timer"] -= delta
		if flash["timer"] <= 0.0:
			keys_to_remove.append(key)
			
	for key in keys_to_remove:
		active_flashes.erase(key)
		
	queue_redraw()

func _draw() -> void:
	if network == null or visuals_map.is_empty():
		return
		
	var view_rect = camera.get_visible_world_rect(128.0) if is_instance_valid(camera) else Rect2(-99999, -99999, 199998, 199998)

	# 1. Draw base connection pipe lines (with frustum culling, batched into 1 draw_multiline call)
	var pipe_pts = PackedVector2Array()
	for conn in network.connections:
		var from_id = conn["from_id"]
		var from_port = int(conn.get("from_port", 0))
		var to_id = conn["to_id"]
		var to_port = int(conn.get("to_port", 0))
		
		var from_vis: BuildingVisual = visuals_map.get(from_id)
		var to_vis: BuildingVisual = visuals_map.get(to_id)
		
		if not is_instance_valid(from_vis) or not is_instance_valid(to_vis):
			continue
			
		if not from_vis.visible and not to_vis.visible:
			continue
			
		var start_pt = from_vis.get_port_global_position(true, from_port)
		var end_pt = to_vis.get_port_global_position(false, to_port)
		
		if not view_rect.has_point(start_pt) and not view_rect.has_point(end_pt):
			continue
			
		pipe_pts.append(start_pt)
		pipe_pts.append(end_pt)
		
	if pipe_pts.size() > 0:
		draw_multiline(pipe_pts, line_color, line_width)

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
