extends Node2D
class_name ConnectionRenderer

## Draws connection lines between building visual nodes with a flowing dot animation.

@export var line_color: Color = Color(0.2, 0.6, 0.9, 0.6) # Sleek transparent blue
@export var line_width: float = 3.0
@export var dot_color: Color = Color(0.5, 0.85, 1.0, 0.9) # Bright glow blue
@export var flow_speed: float = 120.0 # Flow speed in pixels per second
@export var dot_spacing: float = 40.0 # Spacing between flowing dots in pixels

var network: FactoryNetwork
var visuals_map: Dictionary = {} # building_id -> BuildingVisual

func setup(p_network: FactoryNetwork, p_visuals_map: Dictionary) -> void:
	network = p_network
	visuals_map = p_visuals_map

func _process(_delta: float) -> void:
	# Keep redrawing to animate the flow dots
	queue_redraw()

func _draw() -> void:
	if network == null or visuals_map.is_empty():
		return
		
	# Current time in seconds
	var time_sec = Time.get_ticks_msec() / 1000.0
	
	for conn in network.connections:
		var from_id = conn["from_id"]
		var to_id = conn["to_id"]
		
		var from_vis: BuildingVisual = visuals_map.get(from_id)
		var to_vis: BuildingVisual = visuals_map.get(to_id)
		
		if not is_instance_valid(from_vis) or not is_instance_valid(to_vis):
			continue
			
		# Get centers first to find connection points
		var from_center = from_vis.global_position
		var to_center = to_vis.global_position
		
		# Get edge intersection points for cleaner visual connections
		var start_pt = from_vis.get_connection_point_toward(to_center)
		var end_pt = to_vis.get_connection_point_toward(from_center)
		
		# Draw the base connection pipe line
		draw_line(start_pt, end_pt, line_color, line_width)
		
		# Draw flowing resource dots along the pipe at a constant speed
		var distance = start_pt.distance_to(end_pt)
		if distance < 5.0:
			continue
			
		var num_dots = ceil(distance / dot_spacing)
		for i in range(num_dots):
			# Calculate actual travel distance for this dot with looping
			var travel_dist = fmod(time_sec * flow_speed + i * dot_spacing, distance)
			var t = travel_dist / distance
			var dot_pos = start_pt.lerp(end_pt, t)
			draw_circle(dot_pos, 2.5, dot_color)
