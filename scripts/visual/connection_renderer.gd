extends Node2D
class_name ConnectionRenderer

## Draws connection lines between building visual nodes and animates discrete flying resource packets on transfers.

@export var line_color: Color = Color(0.2, 0.6, 0.9, 0.6) # Sleek transparent blue
@export var line_width: float = 3.0
@export var packet_length: float = 30.0 # Length of the flying elongated resource segment
@export var packet_width: float = 5.0 # Width of the resource segment

class ResourcePacket:
	var from_id: int
	var from_port: int
	var to_id: int
	var to_port: int
	var resource_name: String
	var progress: float = 0.0 # Center position in pixels along travel path
	var max_travel_dist: float = 0.0
	var speed: float = 1.0
	var delay: float = 0.0
	var has_triggered_pulse: bool = false

var network: FactoryNetwork
var visuals_map: Dictionary = {} # building_id -> BuildingVisual
var active_packets: Array = []

func setup(p_network: FactoryNetwork, p_visuals_map: Dictionary) -> void:
	if is_instance_valid(network) and network.resource_transferred.is_connected(_on_resource_transferred):
		network.resource_transferred.disconnect(_on_resource_transferred)
		
	network = p_network
	visuals_map = p_visuals_map
	active_packets.clear()
	
	if network != null:
		network.resource_transferred.connect(_on_resource_transferred)

func _on_resource_transferred(from_id: int, from_port: int, to_id: int, to_port: int, resource_name: String, _amount: float, transfer_rate: float) -> void:
	var from_vis: BuildingVisual = visuals_map.get(from_id)
	var to_vis: BuildingVisual = visuals_map.get(to_id)
	
	if not is_instance_valid(from_vis) or not is_instance_valid(to_vis):
		return
		
	var start_pt = from_vis.get_port_global_position(true, from_port)
	var end_pt = to_vis.get_port_global_position(false, to_port)
	var dist = start_pt.distance_to(end_pt)
	if dist < 1.0:
		return
		
	# Calculate delay if an incoming packet to from_id is currently traveling
	var initial_delay = 0.0
	for p in active_packets:
		if p.to_id == from_id:
			var rem_dist = maxf(0.0, p.max_travel_dist - p.progress)
			var rem_time = rem_dist / p.speed if p.speed > 0.0 else 0.0
			initial_delay = maxf(initial_delay, rem_time + p.delay)
			
	var half_len = packet_length * 0.5
	var packet = ResourcePacket.new()
	packet.from_id = from_id
	packet.from_port = from_port
	packet.to_id = to_id
	packet.to_port = to_port
	packet.resource_name = resource_name
	packet.progress = -half_len
	packet.max_travel_dist = dist + half_len
	packet.speed = (dist + packet_length) * maxf(transfer_rate, 0.1)
	packet.delay = initial_delay
	
	if initial_delay <= 0.0:
		packet.has_triggered_pulse = true
		if is_instance_valid(from_vis) and from_vis.has_method("trigger_output_pulse"):
			from_vis.trigger_output_pulse(from_port)
			
	active_packets.append(packet)

func _process(delta: float) -> void:
	var i = 0
	while i < active_packets.size():
		var pkt = active_packets[i]
		if pkt.delay > 0.0:
			pkt.delay -= delta
			if pkt.delay <= 0.0:
				pkt.delay = 0.0
				if not pkt.has_triggered_pulse:
					pkt.has_triggered_pulse = true
					var from_vis: BuildingVisual = visuals_map.get(pkt.from_id)
					if is_instance_valid(from_vis) and from_vis.has_method("trigger_output_pulse"):
						from_vis.trigger_output_pulse(pkt.from_port)
			i += 1
			continue
			
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
		var from_port = int(conn.get("from_port", 0))
		var to_id = conn["to_id"]
		var to_port = int(conn.get("to_port", 0))
		
		var from_vis: BuildingVisual = visuals_map.get(from_id)
		var to_vis: BuildingVisual = visuals_map.get(to_id)
		
		if not is_instance_valid(from_vis) or not is_instance_valid(to_vis):
			continue
			
		var start_pt = from_vis.get_port_global_position(true, from_port)
		var end_pt = to_vis.get_port_global_position(false, to_port)
		
		draw_line(start_pt, end_pt, line_color, line_width)
		
	# 2. Draw flying elongated resource segments
	for pkt in active_packets:
		if pkt.delay > 0.0:
			continue
		var from_vis: BuildingVisual = visuals_map.get(pkt.from_id)
		var to_vis: BuildingVisual = visuals_map.get(pkt.to_id)
		
		if not is_instance_valid(from_vis) or not is_instance_valid(to_vis):
			continue
			
		var start_pt = from_vis.get_port_global_position(true, pkt.from_port)
		var end_pt = to_vis.get_port_global_position(false, pkt.to_port)
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
