extends Node2D
class_name ConnectionRenderer

## Draws connection lines between building visual nodes and animates discrete flying resource packets on transfers.

@export var line_color: Color = Color(0.2, 0.6, 0.9, 0.6) # Sleek transparent blue
@export var line_width: float = 3.0
@export var packet_length: float = 30.0 # Length of the flying elongated resource segment
@export var packet_width: float = 5.0 # Width of the resource segment

class ResourcePacket:
	var from_id: int
	var to_id: int
	var resource_name: String
	var progress: float = 0.0 # Center position in pixels along travel path
	var max_travel_dist: float = 0.0
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

func _on_resource_transferred(from_id: int, to_id: int, resource_name: String, _amount: float, transfer_rate: float) -> void:
	var from_vis: BuildingVisual = visuals_map.get(from_id)
	var to_vis: BuildingVisual = visuals_map.get(to_id)
	
	if not is_instance_valid(from_vis) or not is_instance_valid(to_vis):
		return
		
	var start_pt = from_vis.get_connection_point_toward(to_vis.global_position)
	var end_pt = to_vis.get_connection_point_toward(from_vis.global_position)
	var dist = start_pt.distance_to(end_pt)
	if dist < 1.0:
		return
		
	var half_len = packet_length * 0.5
	var packet = ResourcePacket.new()
	packet.from_id = from_id
	packet.to_id = to_id
	packet.resource_name = resource_name
	packet.progress = -half_len
	packet.max_travel_dist = dist + half_len
	# Entire visual travel path is (dist + packet_length) pixels.
	packet.speed = (dist + packet_length) * maxf(transfer_rate, 0.1)
	active_packets.append(packet)

func _process(delta: float) -> void:
	var i = 0
	while i < active_packets.size():
		var pkt = active_packets[i]
		pkt.progress += pkt.speed * delta
		if pkt.progress >= pkt.max_travel_dist:
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
		
	# 2. Draw flying elongated resource segments
	for pkt in active_packets:
		var from_vis: BuildingVisual = visuals_map.get(pkt.from_id)
		var to_vis: BuildingVisual = visuals_map.get(pkt.to_id)
		
		if not is_instance_valid(from_vis) or not is_instance_valid(to_vis):
			continue
			
		var start_pt = from_vis.get_connection_point_toward(to_vis.global_position)
		var end_pt = to_vis.get_connection_point_toward(from_vis.global_position)
		var total_len = start_pt.distance_to(end_pt)
		if total_len < 1.0:
			continue
			
		var dir = (end_pt - start_pt) / total_len
		var center_dist = pkt.progress
		var half_len = packet_length * 0.5
		
		var head_dist = clampf(center_dist + half_len, 0.0, total_len)
		var tail_dist = clampf(center_dist - half_len, 0.0, total_len)
		
		if tail_dist < head_dist:
			var p_tail = start_pt + dir * tail_dist
			var p_head = start_pt + dir * head_dist
			var color = _get_resource_color(pkt.resource_name)
			draw_line(p_tail, p_head, color, packet_width)

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


