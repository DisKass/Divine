extends PanelContainer
class_name InspectorPanel

## Zone of Responsibility: UI component that displays information about the selected building and manages recipe switching.

signal recipe_selected(recipe_idx: int)



@onready var inspector_details: Label = $VBoxContainer/InspectorDetails
@onready var recipe_container: HBoxContainer = $VBoxContainer/RecipeSelectorContainer
@onready var recipe_button: OptionButton = $VBoxContainer/RecipeSelectorContainer/RecipeOptionButton

func _ready() -> void:
	visible = false
	recipe_container.visible = false
	recipe_button.item_selected.connect(_on_recipe_selected)

func update_inspector_new(b_data: BuildingData, build_mgr: BuildingManager) -> void:
	if b_data == null:
		visible = false
		return
		
	visible = true
	
	var text = "ID: %d\n" % b_data.id
	text += "Type: %s\n" % b_data.type.capitalize()
	text += "Grid Position: %s\n" % str(b_data.grid_position)
	text += "-------------------------\n"
	
	if b_data.type == "portal" and build_mgr != null:
		var m_info = build_mgr.milestones.get_current_milestone()
		if m_info.get("completed_all", false):
			text += "Milestone Status:\n  All Tiers Completed! 🏆\n"
		else:
			text += "Active Milestone:\n"
			text += "  Tier %d: %s\n" % [int(m_info.get("tier", 1)), m_info.get("name", "")]
			text += "  Deliveries Progress:\n"
			var reqs: Dictionary = m_info.get("requirements", {})
			var prog: Dictionary = m_info.get("progress", {})
			for res in reqs:
				var cur_val = int(round(float(prog.get(res, 0.0))))
				var target_val = int(round(float(reqs[res])))
				text += "   • %s: %d / %d\n" % [res.replace("_", " ").capitalize(), cur_val, target_val]
	else:
		if not b_data.active_recipe.is_empty():
			text += "Recipe: %s\n" % b_data.active_recipe.get("name", b_data.active_recipe.get("id", "Unknown"))
			text += "Progress: %.2f / %.1f\n" % [b_data.production_progress, float(b_data.active_recipe.get("duration", 1.0))]
		else:
			text += "Recipe: None\n"
			
		text += "-------------------------\n"
		text += "Inputs:\n"
		for res in b_data.inputs:
			text += "  - %s: %d / %d\n" % [res, int(round(b_data.inputs[res])), int(round(b_data.input_limits.get(res, 20.0)))]
			
		text += "Outputs:\n"
		for res in b_data.outputs:
			text += "  - %s: %d / %d\n" % [res, int(round(b_data.outputs[res])), int(round(b_data.output_limits.get(res, 20.0)))]
		
	inspector_details.text = text

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
