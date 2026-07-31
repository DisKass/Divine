import re
import sys

file_path = "scripts/visual/building_renderer.gd"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Remove StaticUI class
content = re.sub(r'class StaticUI extends Node2D:\n\s+var parent: BuildingRenderer\n\s+func _draw\(\) -> void:\n\s+if is_instance_valid\(parent\):\n\s+parent\._draw_static_layer\(self\)\n\n', '', content)

# 2. Remove static_ui and _static_dirty vars
content = re.sub(r'var static_ui: StaticUI\n', '', content)
content = re.sub(r'var _static_dirty: bool = true\n', '', content)

# 3. Change request_static_redraw
content = re.sub(r'func request_static_redraw\(\) -> void:\n\s+_static_dirty = true', 
                 'func request_static_redraw() -> void:\n\tif is_instance_valid(dynamic_ui):\n\t\tdynamic_ui.queue_redraw()', content)

# 4. Remove _static_dirty = true assignments
content = re.sub(r'\n\s*_static_dirty = true', '', content)

# 5. Remove static_ui initialization
content = re.sub(r'\s*if static_ui == null:\n\s*static_ui = StaticUI\.new\(\)\n\s*static_ui\.parent = self\n\s*static_ui\.z_as_relative = false\n\s*static_ui\.z_index = 4\n\s*static_ui\.name = "StaticUI"\n\s*add_child\(static_ui\)\n*', '\n', content)

# 6. Remove if _static_dirty block in _process
content = re.sub(r'\s*if _static_dirty:\n\s*_static_dirty = false\n\s*if is_instance_valid\(static_ui\):\n\s*static_ui\.queue_redraw\(\)\n', '\n', content)

# 7. Merge _draw_static_layer into _draw_dynamic_layer
# First, find _draw_static_layer and remove it.
static_layer_match = re.search(r'func _draw_static_layer\(canvas: CanvasItem\) -> void:.*?(?=func _draw_building_text)', content, re.DOTALL)
if static_layer_match:
    static_layer_code = static_layer_match.group(0)
    content = content.replace(static_layer_code, '')

# In _draw_dynamic_layer, replace the text drawing part
dynamic_text_pattern = r'\s*var font = _fallback_font\n\s*if font == null: font = ThemeDB\.fallback_font\n\s*if font != null:\n\s*var selected_std_visuals: Array\[BuildingVisual\] = \[\]\n\s*for vis in _cached_visible_visuals:\n\s*if not is_instance_valid\(vis\) or vis\.is_queued_for_deletion\(\): continue\n\s*if vis\.is_dragged or vis\.is_selected:\n\s*if vis\.data and not vis\.data\.is_splitter:\n\s*selected_std_visuals\.append\(vis\)\n\s*if not selected_std_visuals\.is_empty\(\):\n\s*_draw_building_text\(canvas, selected_std_visuals, font\)'

new_dynamic_text = '''	var font = _fallback_font
	if font == null: font = ThemeDB.fallback_font
	if font != null:
		_draw_building_text(canvas, _cached_std_visuals, font)'''

content = re.sub(dynamic_text_pattern, '\n' + new_dynamic_text, content)

# Also fix the borders in dynamic layer
old_borders = r'		if vis\.is_invalid_drag or vis\.is_selected or vis\.is_hovered or vis\.is_dragged:\n\s*var size_px = Vector2\(vis\.data\.size_in_cells \* vis\.cell_size\)\n\s*var top_left = vis\.global_position - size_px / 2\.0\n\s*var rect = Rect2\(top_left, size_px\)\n\s*var border_color = vis\.accent_color\n\s*var border_width = 2\.0\n\s*if vis\.is_invalid_drag:\n\s*border_color = Color\(0\.9, 0\.25, 0\.25\)\n\s*border_width = 3\.0\n\s*elif vis\.is_selected or vis\.is_dragged:\n\s*border_color = Color\(1\.0, 0\.9, 0\.3\)\n\s*border_width = 3\.0\n\s*elif vis\.is_hovered:\n\s*border_color = vis\.accent_color\.lightened\(0\.2\)\n\s*border_width = 2\.0'

new_borders = '''		var size_px = Vector2(vis.data.size_in_cells * vis.cell_size)
		var top_left = vis.global_position - size_px / 2.0
		var rect = Rect2(top_left, size_px)
		var border_color = vis.accent_color.darkened(0.3)
		var border_width = 2.0
		
		if vis.is_invalid_drag:
			border_color = Color(0.9, 0.25, 0.25)
			border_width = 3.0
		elif vis.is_selected or vis.is_dragged:
			border_color = Color(1.0, 0.9, 0.3)
			border_width = 3.0
		elif vis.is_hovered:
			border_color = vis.accent_color.lightened(0.2)
			border_width = 2.0'''

content = re.sub(old_borders, new_borders, content)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Done")
