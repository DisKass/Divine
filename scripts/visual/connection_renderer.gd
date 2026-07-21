extends Node2D
class_name ConnectionRenderer

## Draws connection lines between building visual nodes and animates discrete flying resource packets on transfers.

@export var line_color: Color = Color(0.2, 0.6, 0.9, 0.6) # Sleek transparent blue
@export var line_width: float = 3.0
@export var packet_speed_px: float = 140.0 # Speed in pixels per second

class ResourcePacket:
	var from_id: int
	var to_id: int
	var resource_name: String
	var progress: float = 0.0 # 0.0 to 1.0
	var speed: float = 1.0

var network: FactoryNetwork
var visuals_map: Dictionary = {} # building_id -> BuildingVisual
var active_packets: Array = []

func setup(p_network: FactoryNetwork, p_visuals_map: Dictionary) -> void:
	if is_instance_valid(network) and network.resource_transferred.is_connected(_on_resource_transferred):
		network.resource_transferred.disconnect(_on_resource_transferred)
		
	network = p_network
	visuals_map = p_visuals_map
	
	if network != null:
		network.resource_transferred.connect(_on_resource_transferred)

func _on_resource_transferred(from_id: int, to_id: int, resource_name: String, _amount: float) -> void:
	var from_vis: BuildingVisual = visuals_map.get(from_id)
	var to_vis: BuildingVisual = visuals_map.get(to_id)
	
	if not is_instance_valid(from_vis) or not is_instance_valid(to_vis):
		return
		
	var start_pt = from_vis.get_connection_point_toward(to_vis.global_position)
	var end_pt = to_vis.get_connection_point_toward(from_vis.global_position)
	var dist = start_pt.distance_to(end_pt)
	if dist < 5.0:
		return
		
	var packet = ResourcePacket.new()
	packet.from_id = from_id
	packet.to_id = to_id
	packet.resource_name = resource_name
	packet.progress = 0.0
	packet.speed = packet_speed_px / dist # Complete full path based on distance
	active_packets.append(packet)

func _process(delta: float) -> void:
	var i = 0
	while i < active_packets.size():
		var pkt = active_packets[i]
		pkt.progress += pkt.speed * delta
		if pkt.progress >= 1.0:
			active_packets.remove_at(i)
		else:
			i += 1
			
	queue_redraw()

func _draw() -> void:
	if network == null or visuals_map.is_empty():
		return
		
	# 1. Draw base connection pipe lines
	for conn in network.connections:
		var from_id = conn["from_id"]
		var to_id = conn["to_id"]
		
		var from_vis: BuildingVisual = visuals_map.get(from_id)
		var to_vis: BuildingVisual = visuals_map.get(to_id)
		
		if not is_instance_valid(from_vis) or not is_instance_valid(to_vis):
			continue
			
		var start_pt = from_vis.get_connection_point_toward(to_vis.global_position)
		var end_pt = to_vis.get_connection_point_toward(from_vis.global_position)
		
		draw_line(start_pt, end_pt, line_color, line_width)
		
	# 2. Draw flying resource dots
	for pkt in active_packets:
		var from_vis: BuildingVisual = visuals_map.get(pkt.from_id)
		var to_vis: BuildingVisual = visuals_map.get(pkt.to_id)
		
		if not is_instance_valid(from_vis) or not is_instance_valid(to_vis):
			continue
			
		var start_pt = from_vis.get_connection_point_toward(to_vis.global_position)
		var end_pt = to_vis.get_connection_point_toward(from_vis.global_position)
		var pos = start_pt.lerp(end_pt, clampf(pkt.progress, 0.0, 1.0))
		
		var color = _get_resource_color(pkt.resource_name)
		draw_circle(pos, 3.5, color)

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
		_:
			return Color(0.4, 0.85, 1.0) # Glowing Cyan


