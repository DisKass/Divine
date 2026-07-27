extends Node2D
class_name BuildingVisual

## Visual representation proxy of a building on the grid, syncing state with BuildingData.
## Geometry, port calculations, cached text strings, and state flags are managed here, while rendering is batched by BuildingRenderer.

var data: BuildingData
var cell_size: int = 64
var is_selected: bool = false
var is_hovered: bool = false
var is_invalid_drag: bool = false

# Styling Color based on building type
var accent_color: Color = Color.WHITE

var port_flash_timers: Array[float] = [0.0, 0.0, 0.0]

var _cached_in_ports_local: Array[Vector2] = []
var _cached_out_ports_local: Array[Vector2] = []
var _cached_in_text_lines: Array[String] = []
var _cached_out_text_lines: Array[String] = []
var _cached_title_str: String = ""

var is_flashing: bool = false
var text_dirty: bool = true

func trigger_output_pulse(port_idx: int) -> void:
	while port_flash_timers.size() <= port_idx:
		port_flash_timers.append(0.0)
	port_flash_timers[port_idx] = 0.35
	is_flashing = true

func setup(p_data: BuildingData, p_cell_size: int) -> void:
	data = p_data
	cell_size = p_cell_size
	
	match data.type:
		"portal":
			accent_color = Color(1.0, 0.65, 0.2)
		"miner", "miner_iron", "miner_coal", "miner_crystal":
			accent_color = Color(0.9, 0.45, 0.1)
		"smelter":
			accent_color = Color(0.95, 0.25, 0.25)
		"converter", "constructor", "crusher":
			accent_color = Color(0.2, 0.8, 0.5)
		"assembler":
			accent_color = Color(0.3, 0.5, 0.95)
		"extractor":
			accent_color = Color(0.85, 0.35, 0.85)
		"infuser", "alchemy_lab":
			accent_color = Color(0.9, 0.5, 0.9)
		"artifact_altar":
			accent_color = Color(0.9, 0.8, 0.2)
		"seller":
			accent_color = Color(0.2, 0.85, 0.4)
		"splitter_2", "splitter_3":
			accent_color = Color(0.9, 0.9, 0.3)
		_:
			accent_color = Color(0.7, 0.7, 0.7)
			
	var size_px = Vector2(data.size_in_cells * cell_size)
	position = Vector2(data.grid_position) * cell_size + size_px / 2.0
	_update_ports_cache()
	text_dirty = true
	update_text_cache()

func _update_ports_cache() -> void:
	_cached_in_ports_local.clear()
	_cached_out_ports_local.clear()
	if data == null:
		return
		
	var recipe_ctx = {"inputs": data.inputs, "outputs": data.outputs}
	var out_count = BuildingData.get_output_ports_count(data.type, recipe_ctx)
	for i in range(out_count):
		_cached_out_ports_local.append(_calc_port_global_position(true, i) - global_position)
		
	var in_count = BuildingData.get_input_ports_count(data.type, recipe_ctx)
	for i in range(in_count):
		_cached_in_ports_local.append(_calc_port_global_position(false, i) - global_position)

func get_port_global_position(is_output: bool, port_idx: int) -> Vector2:
	if data == null:
		return global_position
		
	if is_output:
		if port_idx >= 0 and port_idx < _cached_out_ports_local.size():
			return global_position + _cached_out_ports_local[port_idx]
	else:
		if port_idx >= 0 and port_idx < _cached_in_ports_local.size():
			return global_position + _cached_in_ports_local[port_idx]
			
	return _calc_port_global_position(is_output, port_idx)

func _calc_port_global_position(is_output: bool, port_idx: int) -> Vector2:
	if data == null:
		return global_position
		
	var half_width = data.size_in_cells.x * cell_size / 2.0
	var half_height = data.size_in_cells.y * cell_size / 2.0
	
	if data.type.begins_with("splitter"):
		if not is_output:
			return Vector2(global_position.x - half_width, global_position.y)
		else:
			var total_ports = BuildingData.get_output_ports_count(data.type)
			port_idx = clamp(port_idx, 0, total_ports - 1)
			if total_ports <= 2:
				var offset_y = -half_height * 0.45 if port_idx == 0 else half_height * 0.45
				return Vector2(global_position.x + half_width, global_position.y + offset_y)
			else:
				var offsets = [-half_height * 0.55, 0.0, half_height * 0.55]
				return Vector2(global_position.x + half_width, global_position.y + offsets[port_idx])
	
	var recipe_ctx = {"inputs": data.inputs, "outputs": data.outputs}
	var in_count = BuildingData.get_input_ports_count(data.type, recipe_ctx)
	var out_count = BuildingData.get_output_ports_count(data.type, recipe_ctx)
	var total_ports = out_count if is_output else in_count
	if total_ports <= 0:
		return global_position
		
	port_idx = clamp(port_idx, 0, total_ports - 1)
	var side_x = half_width if is_output else -half_width
	var header_height = float(cell_size)
	var start_y = global_position.y - half_height + header_height
	var end_y = global_position.y + half_height - 3.0
	
	var total_entries = in_count + out_count
	if total_entries <= 0:
		return Vector2(global_position.x + side_x, global_position.y)
		
	var entry_idx = (in_count + port_idx) if is_output else port_idx
	var step = (end_y - start_y) / float(total_entries)
	var port_y = start_y + (float(entry_idx) + 0.5) * step
	return Vector2(global_position.x + side_x, port_y)

var _cached_in_multiline_str: String = ""
var _cached_out_multiline_str: String = ""
var _last_ui_version: int = -1

static var _resource_prefix_cache: Dictionary = {}

static func format_resource_line(res_key: String, val: int, max_width: float, font: Font, font_size: int = 9) -> String:
	var cache_key = "%s_%d" % [res_key, int(max_width)]
	var prefix = _resource_prefix_cache.get(cache_key, "")
	
	if prefix == "":
		var short_name = res_key.replace("iron_", "").replace("_", " ").capitalize()
		var test_suffix = ": 9999"
		var full_str = "%s%s" % [short_name, test_suffix]
		
		if font == null or max_width <= 0.0 or font.get_string_size(full_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width:
			prefix = short_name
		else:
			var name_len = short_name.length()
			prefix = "..."
			for l in range(name_len - 1, 0, -1):
				var candidate = "%s..." % short_name.substr(0, l)
				if font.get_string_size(candidate + test_suffix, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width:
					prefix = candidate
					break
					
		_resource_prefix_cache[cache_key] = prefix
		
	return "%s: %d" % [prefix, val]

func update_text_cache() -> bool:
	if data == null:
		return false
	if data.ui_version != _last_ui_version:
		_last_ui_version = data.ui_version
		text_dirty = true
	if not text_dirty:
		return false
	text_dirty = false
	_cached_title_str = data.type.capitalize()
	_cached_in_text_lines.clear()
	_cached_out_text_lines.clear()
	
	var font = ThemeDB.fallback_font
	var max_width = float(data.size_in_cells.x * cell_size - 8)
	
	for k in data.inputs:
		if not k.begins_with("_"):
			var val = int(round(data.inputs[k]))
			_cached_in_text_lines.append(format_resource_line(k, val, max_width, font, 9))
			
	for k in data.outputs:
		if not k.begins_with("_") and k != "credits":
			var val = int(round(data.outputs[k]))
			_cached_out_text_lines.append(format_resource_line(k, val, max_width, font, 9))
			
	_cached_in_multiline_str = "\n".join(_cached_in_text_lines)
	_cached_out_multiline_str = "\n".join(_cached_out_text_lines)
	return true

func request_overlay_redraw() -> void:
	pass

func _process_port_flashes(delta: float) -> bool:
	var active = false
	for i in range(port_flash_timers.size()):
		if port_flash_timers[i] > 0.0:
			port_flash_timers[i] = maxf(0.0, port_flash_timers[i] - delta)
			active = true
	return active

func update_culling(visible_world_rect: Rect2, _zoom_level: float = 1.0) -> bool:
	if data == null:
		return false
		
	var size_px = Vector2(data.size_in_cells * cell_size)
	var half_size = size_px * 0.5
	var my_min = global_position - half_size
	var my_max = global_position + half_size
	
	var is_in_view = not (my_max.x < visible_world_rect.position.x or my_min.x > visible_world_rect.end.x or \
						  my_max.y < visible_world_rect.position.y or my_min.y > visible_world_rect.end.y)
						  
	visible = is_in_view
	return is_in_view

func get_input_port_for_resource(res_name: String) -> int:
	if data == null:
		return 0
	var in_keys = []
	for k in data.inputs.keys():
		if not k.begins_with("_"):
			in_keys.append(k)
	for i in range(in_keys.size()):
		if in_keys[i] == res_name:
			return i
	return 0



func get_output_port_at_position(click_global_pos: Vector2) -> int:
	if data == null:
		return 0
	var recipe_ctx = {"inputs": data.inputs, "outputs": data.outputs}
	var total_ports = BuildingData.get_output_ports_count(data.type, recipe_ctx)
	if total_ports <= 1:
		return 0
		
	var best_idx = 0
	var best_dist = INF
	for i in range(total_ports):
		var port_pos = get_port_global_position(true, i)
		var dist = click_global_pos.distance_to(port_pos)
		if dist < best_dist:
			best_dist = dist
			best_idx = i
	return best_idx

func get_connection_point_toward(target_pos: Vector2) -> Vector2:
	var my_center = global_position
	var dir = (target_pos - my_center).normalized()
	
	var half_width = data.size_in_cells.x * cell_size / 2.0
	var half_height = data.size_in_cells.y * cell_size / 2.0
	
	if dir.x == 0:
		return my_center + Vector2(0, signf(dir.y) * half_height)
		
	var t_x = half_width / absf(dir.x)
	var t_y = half_height / absf(dir.y)
	var t = minf(t_x, t_y)
	
	return my_center + dir * t
