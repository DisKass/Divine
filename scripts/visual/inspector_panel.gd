extends PanelContainer
class_name InspectorPanel

## Zone of Responsibility: UI component that displays information about the selected building and manages recipe switching.

signal recipe_selected(recipe_idx: int)
signal vault_mode_changed(building_id: int, new_mode: String)

@onready var inspector_details: Label = $VBoxContainer/InspectorDetails
@onready var recipe_container: HBoxContainer = $VBoxContainer/RecipeSelectorContainer
@onready var recipe_button: OptionButton = $VBoxContainer/RecipeSelectorContainer/RecipeOptionButton

var unequip_btn: Button
var vault_toggle_btn: Button
var vault_toggle_rt: RichTextLabel
var _inspected_vault_mode: String = ""

func _ready() -> void:
	visible = false
	recipe_container.visible = false
	recipe_button.item_selected.connect(_on_recipe_selected)
	
	vault_toggle_btn = Button.new()
	vault_toggle_btn.visible = false
	vault_toggle_btn.custom_minimum_size = Vector2(0, 32)
	vault_toggle_btn.pressed.connect(_on_vault_toggle_pressed)
	
	var cc = CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vault_toggle_btn.add_child(cc)
	
	vault_toggle_rt = RichTextLabel.new()
	vault_toggle_rt.bbcode_enabled = true
	vault_toggle_rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vault_toggle_rt.fit_content = true
	vault_toggle_rt.autowrap_mode = TextServer.AUTOWRAP_OFF
	cc.add_child(vault_toggle_rt)
	
	$VBoxContainer.add_child(vault_toggle_btn)
	
	unequip_btn = Button.new()
	unequip_btn.text = "Unequip Artifact"
	unequip_btn.visible = false
	$VBoxContainer.add_child(unequip_btn)
	unequip_btn.pressed.connect(_on_unequip_pressed)

var _inspected_building_id: int = -1
var _inspected_recipe_id: String = ""

func update_inspector_new(b_data: BuildingData, state: GameState) -> void:
	inspector_details.remove_theme_color_override("font_color")
	var show_unequip = false
	if b_data == null:
		unequip_btn.visible = false
		vault_toggle_btn.visible = false
		visible = false
		_inspected_building_id = -1
		_inspected_recipe_id = ""
		_inspected_vault_mode = ""
		return
		
	visible = true
	
	var text = "ID: %d\n" % b_data.id
	text += "Type: %s\n" % b_data.type.capitalize()
	text += "Grid Position: %s\n" % str(b_data.grid_position)
	text += "-------------------------\n"
	
	if b_data.type == "portal" and state != null:
		var m_info = MilestoneSystem.get_current_milestone(state)
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
	elif b_data.type == "artifact_altar":
		if b_data.held_artifact.is_empty():
			text += "Artifact: None\n"
		else:
			var item = ItemData.from_dict(b_data.held_artifact)
			var base_cfg = ArtifactSystem.artifact_configs.get(item.base_id)
			var a_name = base_cfg.name if base_cfg else item.base_id
			text += "Artifact: %s\n" % a_name
			text += "AoE Size: %d\n" % item.get_effective_aoe_size()

			text += "--- Stats ---\n"
			var lines = item.get_formatted_affix_lines()
			if lines.is_empty():
				text += "  (White Artifact - No Affixes)\n"
			else:
				for line in lines:
					text += "  • %s\n" % line
			show_unequip = true

	else:
		if not b_data.active_recipe.is_empty():
			text += "Recipe: %s\n" % b_data.active_recipe.get("name", b_data.active_recipe.get("id", "Unknown"))
			text += "Progress: %.2f / %.1f\n" % [b_data.production_progress, float(b_data.active_recipe.get("duration", 1.0))]
		else:
			text += "Recipe: None\n"
			
		text += "-------------------------\n"
		text += "Inputs:\n"
		for slot in b_data.input_slots:
			var res_name = slot.current_item
			if res_name == "" and slot.accepted_tags.size() > 0:
				res_name = slot.accepted_tags[0]
			if res_name != "":
				text += "  - %s: %d / %d\n" % [res_name.replace("_", " ").capitalize(), int(round(slot.amount)), int(round(slot.capacity))]
			
		text += "Outputs:\n"
		for slot in b_data.output_slots:
			var res_name = slot.current_item
			if res_name == "" and slot.accepted_tags.size() > 0:
				res_name = slot.accepted_tags[0]
			if res_name != "":
				text += "  - %s: %d / %d\n" % [res_name.replace("_", " ").capitalize(), int(round(slot.amount)), int(round(slot.capacity))]
		
	inspector_details.text = text
	unequip_btn.visible = show_unequip
	
	if b_data.type == "vault_gateway":
		_inspected_vault_mode = b_data.vault_gateway_mode
		vault_toggle_btn.visible = true
		if _inspected_vault_mode == "store":
			vault_toggle_rt.text = "[color=#ffe64d]Store[/color] / Retrieve"
		else:
			vault_toggle_rt.text = "Store / [color=#ffe64d]Retrieve[/color]"
	else:
		vault_toggle_btn.visible = false
		_inspected_vault_mode = ""

	var active_recipe_id = b_data.active_recipe.get("id", "")
	var possible_recipes = Recipes.DATA.get(b_data.type, [])
	if possible_recipes.size() > 1:
		recipe_container.visible = true
		if b_data.id != _inspected_building_id or active_recipe_id != _inspected_recipe_id:
			_inspected_building_id = b_data.id
			_inspected_recipe_id = active_recipe_id
			
			recipe_button.clear()
			var select_idx = 0
			for i in range(possible_recipes.size()):
				var recipe = possible_recipes[i]
				recipe_button.add_item(recipe.get("name", recipe.get("id", "Unknown")))
				if recipe.get("id", "") == active_recipe_id:
					select_idx = i
					
			if recipe_button.item_selected.is_connected(_on_recipe_selected):
				recipe_button.item_selected.disconnect(_on_recipe_selected)
			recipe_button.selected = select_idx
			recipe_button.item_selected.connect(_on_recipe_selected)
	else:
		recipe_container.visible = false
		_inspected_building_id = b_data.id
		_inspected_recipe_id = active_recipe_id

func update_multi_inspector(selected_count: int, total_cost: Dictionary = {}, can_afford: bool = true) -> void:
	if selected_count <= 0:
		visible = false
		_inspected_building_id = -1
		_inspected_recipe_id = ""
		return

	visible = true
	recipe_container.visible = false
	_inspected_building_id = -1
	_inspected_recipe_id = ""

	var text = "Selected Buildings: %d\n" % selected_count
	if not total_cost.is_empty():
		text += "-------------------------\n"
		text += "Total Cost:\n"
		for res in total_cost:
			text += "  • %s: %.1f\n" % [res.replace("_", " ").capitalize(), total_cost[res]]
		text += "Status: %s\n" % ("Affordable ✓" if can_afford else "Insufficient Funds ✗")
		
		if not can_afford:
			inspector_details.add_theme_color_override("font_color", Color(0.95, 0.35, 0.25))
		else:
			inspector_details.add_theme_color_override("font_color", Color(0.2, 0.85, 0.4))
	else:
		inspector_details.remove_theme_color_override("font_color")

	inspector_details.text = text
	unequip_btn.visible = false
	vault_toggle_btn.visible = false

func _on_recipe_selected(idx: int) -> void:
	recipe_selected.emit(idx)

signal unequip_requested(building_id: int)
func _on_unequip_pressed() -> void:
	if _inspected_building_id != -1:
		unequip_requested.emit(_inspected_building_id)

func _on_vault_toggle_pressed() -> void:
	if _inspected_building_id != -1:
		var new_mode = "retrieve" if _inspected_vault_mode == "store" else "store"
		vault_mode_changed.emit(_inspected_building_id, new_mode)
