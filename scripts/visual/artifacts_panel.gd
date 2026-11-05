extends PanelContainer
class_name ArtifactsPanel

## Zone of Responsibility: Modal UI Panel displaying global Artifact Inventory (max 5 items).
## Supports dragging items to equip them into Altars.

signal closed

@onready var inventory_vbox: VBoxContainer = $MarginContainer/InventoryVBox
@onready var empty_inventory_label: Label = $MarginContainer/InventoryVBox/EmptyLabel

var state: GameState
var inventory_cards: Array[Control] = []

func _ready() -> void:
	pass

func setup_new(p_state: GameState) -> void:
	if state == p_state:
		return
		
	if state != null and state.artifacts_changed.is_connected(update_panel):
		state.artifacts_changed.disconnect(update_panel)
		
	state = p_state
	
	if state != null and not state.artifacts_changed.is_connected(update_panel):
		state.artifacts_changed.connect(update_panel)
	
	_build_inventory_ui()
	update_panel()

func _build_inventory_ui() -> void:
	for c in inventory_cards:
		c.queue_free()
	inventory_cards.clear()
	
	for i in range(ArtifactSystem.MAX_INVENTORY_SIZE):
		var card = _create_inventory_card()
		inventory_vbox.add_child(card)
		inventory_cards.append(card)

func _create_inventory_card() -> Control:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(120, 110)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.12, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.4, 1.0, 0.5)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 4
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var margin = MarginContainer.new()
	margin.name = "MarginContainer"
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	card.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)
	
	var title_lbl = Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.add_theme_font_size_override("font_size", 11)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(title_lbl)
	
	var div = ColorRect.new()
	div.custom_minimum_size = Vector2(0, 2)
	div.color = Color(0.8, 0.4, 1.0, 0.8)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(div)
	
	var desc_lbl = Label.new()
	desc_lbl.name = "DescLabel"
	desc_lbl.add_theme_font_size_override("font_size", 9)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_lbl)
	
	# Enable Drag & Drop and Hover
	var script = GDScript.new()
	script.source_code = """
extends PanelContainer
var item_uid: String = ""

func _ready():
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_unhover)

func _on_hover():
	var style = get_theme_stylebox("panel").duplicate()
	style.bg_color = Color(0.12, 0.15, 0.18, 0.95)
	style.border_color = Color(0.8, 0.4, 1.0, 0.9)
	style.shadow_color = Color(0.8, 0.4, 1.0, 0.15)
	style.shadow_size = 6
	add_theme_stylebox_override("panel", style)

func _on_unhover():
	var style = get_theme_stylebox("panel").duplicate()
	style.bg_color = Color(0.08, 0.1, 0.12, 0.95)
	style.border_color = Color(0.8, 0.4, 1.0, 0.5)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 4
	add_theme_stylebox_override("panel", style)

func _get_drag_data(_at_position: Vector2):
	if item_uid == "":
		return null
	var preview = Label.new()
	preview.text = "Dragging Artifact..."
	set_drag_preview(preview)
	
	# The dragged data is the action info
	return {
		"type": "artifact",
		"uid": item_uid
	}
"""
	script.reload()
	card.set_script(script)
	
	return card

func update_panel() -> void:
	if state == null: return
	
	var inventory = state.progress.artifact_inventory
	var has_items = inventory.size() > 0
	empty_inventory_label.visible = not has_items
	
	ArtifactSystem.ensure_configs_loaded()
	
	for i in range(ArtifactSystem.MAX_INVENTORY_SIZE):
		var card = inventory_cards[i]
		if i < inventory.size():
			var item_dict = inventory[i]
			var item = ItemData.from_dict(item_dict)
			var config: ArtifactData = ArtifactSystem.artifact_configs.get(item.base_id)
			
			var title_lbl: Label = card.get_node("MarginContainer/VBoxContainer/TitleLabel")
			var desc_lbl: Label = card.get_node("MarginContainer/VBoxContainer/DescLabel")
			
			title_lbl.text = config.name if config else item.base_id
			
			var desc_parts = []
			desc_parts.append("AoE: %d" % item.get_effective_aoe_size())

			var lines = item.get_formatted_affix_lines()
			if lines.is_empty():
				desc_parts.append("(White)")
			else:
				for line in lines:
					desc_parts.append(line)
			desc_lbl.text = "\n".join(desc_parts)

			
			card.visible = true
			card.set("item_uid", item.uid)
		else:
			card.visible = false
			card.set("item_uid", "")
