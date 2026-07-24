class_name GameCamera
extends Camera2D

## Handles panning (RMB/MMB drag) and smooth zoom (scroll wheel) in 2D space.

@export var min_zoom: float = 0.2
@export var max_zoom: float = 3.0
@export var zoom_speed: float = 1.2
@export var zoom_lerp_speed: float = 15.0

var _target_zoom: float = 1.0
var is_panning: bool = false

func _ready() -> void:
	_target_zoom = zoom.x

func _process(delta: float) -> void:
	# Smoothly interpolate to target zoom
	var next_zoom = lerpf(zoom.x, _target_zoom, zoom_lerp_speed * delta)
	zoom = Vector2(next_zoom, next_zoom)

func _unhandled_input(event: InputEvent) -> void:
	# Zooming via scroll wheel
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_target_zoom = clampf(_target_zoom * zoom_speed, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_target_zoom = clampf(_target_zoom / zoom_speed, min_zoom, max_zoom)
			
	# Panning: Motion (panning status is controlled by MainGame)
	elif event is InputEventMouseMotion and is_panning:
		# Drag amount is relative mouse movement, scaled by zoom so speed feels consistent
		position -= event.relative / zoom.x

## Returns exact camera viewport bounding rectangle in world space coordinates.
func get_visible_world_rect(margin: float = 128.0) -> Rect2:
	var viewport = get_viewport()
	if viewport == null:
		return Rect2(-99999, -99999, 199998, 199998)
	var view_size = viewport.get_visible_rect().size
	var current_zoom = maxf(zoom.x, 0.01)
	var half_size = (view_size / current_zoom) * 0.5 + Vector2(margin, margin)
	var min_pos = global_position - half_size
	var size = half_size * 2.0
	return Rect2(min_pos, size)
