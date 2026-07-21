class_name GridRenderer
extends Node2D

## Procedurally draws an infinite 2D grid that pans and scales with the camera.

@export var cell_size: int = 32
@export var grid_color: Color = Color(0.15, 0.18, 0.22, 0.4)
@export var major_grid_color: Color = Color(0.25, 0.3, 0.35, 0.6)
@export var axis_color: Color = Color(0.3, 0.6, 1.0, 0.4)

@export var line_width: float = 1.0
@export var major_line_width: float = 1.5
@export var axis_line_width: float = 2.0

var _last_transform: Transform2D

func _process(_delta: float) -> void:
	# Force redraw only if the camera view matrix changes
	var current_transform = get_viewport().canvas_transform
	if current_transform != _last_transform:
		_last_transform = current_transform
		queue_redraw()

@warning_ignore("integer_division")
func _draw() -> void:
	var canvas_transform = get_viewport().canvas_transform
	var screen_transform = canvas_transform.inverse()
	var view_size = get_viewport_rect().size
	
	var top_left = screen_transform * Vector2.ZERO
	var bottom_right = screen_transform * view_size
	
	# Determine bounds
	var start_x = (int(top_left.x) / cell_size - 1) * cell_size
	var end_x = (int(bottom_right.x) / cell_size + 1) * cell_size
	var start_y = (int(top_left.y) / cell_size - 1) * cell_size
	var end_y = (int(bottom_right.y) / cell_size + 1) * cell_size
	
	# Draw normal and major vertical grid lines
	for x in range(start_x, end_x + 1, cell_size):
		if x == 0:
			continue # Handled by axis drawing
		var is_major = (x / cell_size) % 5 == 0
		var color = major_grid_color if is_major else grid_color
		var width = major_line_width if is_major else line_width
		draw_line(Vector2(x, start_y), Vector2(x, end_y), color, width)
		
	# Draw normal and major horizontal grid lines
	for y in range(start_y, end_y + 1, cell_size):
		if y == 0:
			continue # Handled by axis drawing
		var is_major = (y / cell_size) % 5 == 0
		var color = major_grid_color if is_major else grid_color
		var width = major_line_width if is_major else line_width
		draw_line(Vector2(start_x, y), Vector2(end_x, y), color, width)
		
	# Draw X & Y axes (origin lines)
	if start_x <= 0 and end_x >= 0:
		draw_line(Vector2(0, start_y), Vector2(0, end_y), axis_color, axis_line_width)
	if start_y <= 0 and end_y >= 0:
		draw_line(Vector2(start_x, 0), Vector2(end_x, 0), axis_color, axis_line_width)
