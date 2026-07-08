extends PanelContainer
class_name InspectorPanel

## UI component that displays information about the selected building and manages recipe switching.

signal recipe_selected(recipe_idx: int)

const Recipes = preload("res://scripts/core/recipes.gd")

var inspector_details: Label
var recipe_container: HBoxContainer
var recipe_button: OptionButton

func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(250, 0)
	set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	offset_left = -250
	offset_right = 0
	offset_top = 60
	offset_bottom = -160
	
	var insp_style = StyleBoxFlat.new()
	insp_style.bg_color = Color(0.08, 0.1, 0.12, 0.9)
	insp_style.border_width_left = 2
	insp_style.border_color = Color(0.3, 0.6, 1.0, 0.3)
	add_theme_stylebox_override("panel", insp_style)
	
	var insp_vbox = VBoxContainer.new()
	insp_vbox.add_theme_constant_override("separation", 10)
	add_child(insp_vbox)
	
	var insp_title = Label.new()
	insp_title.text = "Building Inspector"
	insp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	insp_title.add_theme_font_size_override("font_size", 14)
	insp_title.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
	insp_vbox.add_child(insp_title)
	
	var insp_sep = ColorRect.new()
	insp_sep.custom_minimum_size = Vector2(0, 2)
	insp_sep.color = Color(0.3, 0.6, 1.0, 0.3)
	insp_vbox.add_child(insp_sep)
	
	inspector_details = Label.new()
	inspector_details.text = ""
	inspector_details.add_theme_font_size_override("font_size", 11)
	insp_vbox.add_child(inspector_details)
	
	# Recipe Selector UI container
	recipe_container = HBoxContainer.new()
	recipe_container.name = "RecipeSelectorContainer"
	recipe_container.visible = false
	insp_vbox.add_child(recipe_container)
	
	var recipe_lbl = Label.new()
	recipe_lbl.text = "Recipe:"
	recipe_lbl.add_theme_font_size_override("font_size", 11)
	recipe_container.add_child(recipe_lbl)
	
	recipe_button = OptionButton.new()
	recipe_button.name = "RecipeOptionButton"
	recipe_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_button.add_theme_font_size_override("font_size", 10)
	recipe_container.add_child(recipe_button)
	
	recipe_button.item_selected.connect(_on_recipe_selected)

## Updates the inspector panel with the given building data.
func update_inspector(b_data: BuildingData) -> void:
	if b_data == null:
		visible = false
		return
		
	visible = true
	
	var text = "ID: %d\n" % b_data.id
	text += "Type: %s\n" % b_data.type.capitalize()
	text += "Grid Position: %s\n" % str(b_data.grid_position)
	text += "-------------------------\n"
	
	if not b_data.active_recipe.is_empty():
		text += "Recipe: %s\n" % b_data.active_recipe.get("name", b_data.active_recipe.get("id", "Unknown"))
		text += "Progress: %.2f / %.1f\n" % [b_data.production_progress, float(b_data.active_recipe.get("duration", 1.0))]
	else:
		text += "Recipe: None\n"
		
	text += "-------------------------\n"
	text += "Inputs:\n"
	for res in b_data.inputs:
		text += "  - %s: %.1f / %.1f\n" % [res, b_data.inputs[res], b_data.input_limits.get(res, 20.0)]
		
	text += "Outputs:\n"
	for res in b_data.outputs:
		text += "  - %s: %.1f / %.1f\n" % [res, b_data.outputs[res], b_data.output_limits.get(res, 20.0)]
		
	inspector_details.text = text

	# Update Recipe OptionButton
	var possible_recipes = Recipes.DATA.get(b_data.type, [])
	if possible_recipes.size() > 1:
		recipe_container.visible = true
		recipe_button.clear()
		
		var active_recipe_id = b_data.active_recipe.get("id", "")
		var select_idx = 0
		for i in range(possible_recipes.size()):
			var recipe = possible_recipes[i]
			recipe_button.add_item(recipe.get("name", recipe.get("id", "Unknown")))
			if recipe.get("id", "") == active_recipe_id:
				select_idx = i
				
		recipe_button.item_selected.disconnect(_on_recipe_selected)
		recipe_button.selected = select_idx
		recipe_button.item_selected.connect(_on_recipe_selected)
	else:
		recipe_container.visible = false

func _on_recipe_selected(idx: int) -> void:
	recipe_selected.emit(idx)
