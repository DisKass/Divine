extends PanelContainer
class_name ArtifactsPanel

## Zone of Responsibility: Modal UI Panel displaying global Artifact Inventory and Equipment Slots.

signal closed

@onready var close_btn: Button = $MarginContainer/VBoxContainer/HeaderHBox/CloseBtn
@onready var slots_hbox: HBoxContainer = $MarginContainer/VBoxContainer/SlotsHBox
@onready var summary_label: Label = $MarginContainer/VBoxContainer/SummaryLabel
@onready var inventory_vbox: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/InventoryVBox
@onready var empty_inventory_label: Label = $MarginContainer/VBoxContainer/ScrollContainer/InventoryVBox/EmptyLabel

var art_mgr: ArtifactsManager
var slot_cards: Array[Dictionary] = []
var inventory_cards: Dictionary = {}

func _ready() -> void:
	close_btn.pressed.connect(func():
		visible = false
		closed.emit()
	)

func setup_new(p_art_mgr: ArtifactsManager) -> void:
	art_mgr = p_art_mgr
	
	if slot_cards.is_empty():
		_build_slots()
		_build_inventory()
		
	if not art_mgr.artifact_crafted.is_connected(_on_artifact_crafted):
		art_mgr.artifact_crafted.connect(_on_artifact_crafted)
		art_mgr.artifact_equipped.connect(_on_artifact_equipped)
		art_mgr.artifact_unequipped.connect(_on_artifact_unequipped)

func _build_slots() -> void:
	for i in range(2):
		var slot_panel = PanelContainer.new()
		slot_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_panel.custom_minimum_size = Vector2(0, 64)
		
		var p_style = StyleBoxFlat.new()
		p_style.bg_color = Color(0.12, 0.15, 0.22, 0.9)
		p_style.border_width_left = 2
		p_style.border_width_top = 2
		p_style.border_width_right = 2
		p_style.border_width_bottom = 2
		p_style.border_color = Color(0.3, 0.5, 0.7, 0.6)
		p_style.corner_radius_top_left = 6
		p_style.corner_radius_top_right = 6
		p_style.corner_radius_bottom_left = 6
		p_style.corner_radius_bottom_right = 6
		slot_panel.add_theme_stylebox_override("panel", p_style)
		
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_bottom", 6)
		slot_panel.add_child(margin)
		
		var hbox = HBoxContainer.new()
		margin.add_child(hbox)
		
		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 2)
		hbox.add_child(vbox)
		
		var title_lbl = Label.new()
		title_lbl.add_theme_font_size_override("font_size", 11)
		title_lbl.add_theme_color_override("font_color", Color.WHITE)
		vbox.add_child(title_lbl)
		
		var desc_lbl = Label.new()
		desc_lbl.add_theme_font_size_override("font_size", 9)
		desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
		vbox.add_child(desc_lbl)
		
		var unequip_btn = Button.new()
		unequip_btn.text = "Unequip"
		unequip_btn.custom_minimum_size = Vector2(65, 0)
		unequip_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		unequip_btn.pressed.connect(func():
			if is_instance_valid(art_mgr):
				art_mgr.unequip_artifact(i)
		)
		hbox.add_child(unequip_btn)
		
		slots_hbox.add_child(slot_panel)
		slot_cards.append({
			"title_label": title_lbl,
			"desc_label": desc_lbl,
			"unequip_button": unequip_btn
		})

func _build_inventory() -> void:
	for art_id in art_mgr.artifact_configs:
		var config: ArtifactData = art_mgr.artifact_configs[art_id]
		
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 56)
		card.visible = false
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.13, 0.18, 0.85)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.4, 0.6, 0.8, 0.4)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		card.add_theme_stylebox_override("panel", style)
		
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_top", 4)
		margin.add_theme_constant_override("margin_bottom", 4)
		card.add_child(margin)
		
		var hbox = HBoxContainer.new()
		margin.add_child(hbox)
		
		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 2)
		hbox.add_child(vbox)
		
		var title_lbl = Label.new()
		title_lbl.add_theme_font_size_override("font_size", 11)
		title_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		vbox.add_child(title_lbl)
		
		var desc_lbl = Label.new()
		desc_lbl.text = config.description
		desc_lbl.add_theme_font_size_override("font_size", 9)
		desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
		vbox.add_child(desc_lbl)
		
		var equip_btn = Button.new()
		equip_btn.text = "Equip"
		equip_btn.custom_minimum_size = Vector2(65, 0)
		equip_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		equip_btn.pressed.connect(func():
			if is_instance_valid(art_mgr):
				art_mgr.equip_artifact(art_id)
		)
		hbox.add_child(equip_btn)
		
		inventory_vbox.add_child(card)
		inventory_cards[art_id] = {
			"card_panel": card,
			"title_label": title_lbl,
			"equip_button": equip_btn
		}

func update_panel() -> void:
	if art_mgr == null: return
		
	# Update slots
	for i in range(2):
		var refs: Dictionary = slot_cards[i]
		var art_id = art_mgr.equipped_artifacts[i] if i < art_mgr.equipped_artifacts.size() else ""
		var title_lbl: Label = refs["title_label"]
		var desc_lbl: Label = refs["desc_label"]
		var unequip_btn: Button = refs["unequip_button"]
		
		if art_id != "" and art_mgr.artifact_configs.has(art_id):
			var config: ArtifactData = art_mgr.artifact_configs[art_id]
			title_lbl.text = "Slot %d: %s" % [i + 1, config.name if config.name != "" else art_id]
			desc_lbl.text = config.description
			unequip_btn.visible = true
		else:
			title_lbl.text = "Slot %d: [ Empty ]" % [i + 1]
			desc_lbl.text = "Equip an artifact from inventory"
			unequip_btn.visible = false
			
	# Update Summary
	var summary_parts: Array[String] = []
	var f_bonus = art_mgr.modifier_manager.get_multiplier("factory_speed") - 1.0 # Only works for artifacts roughly, we can just display the total multiplier
	if f_bonus > 0.001: summary_parts.append("+%.0f%% Factory Speed" % (f_bonus * 100.0))
	var m_bonus = art_mgr.modifier_manager.get_multiplier("miner_speed") - 1.0
	if m_bonus > 0.001: summary_parts.append("+%.0f%% Mining Speed" % (m_bonus * 100.0))
	var l_bonus = art_mgr.modifier_manager.get_multiplier("logistics_transfer") - 1.0
	if l_bonus > 0.001: summary_parts.append("+%.0f%% Logistics" % (l_bonus * 100.0))
	var s_bonus = art_mgr.modifier_manager.get_multiplier("sell_price_mult") - 1.0
	if s_bonus > 0.001: summary_parts.append("+%.0f%% Sell Income" % (s_bonus * 100.0))
	
	if summary_parts.is_empty():
		summary_label.text = "Active Modifiers: None"
	else:
		summary_label.text = "Active Modifiers: " + ", ".join(summary_parts)
		
	# Update Inventory
	var has_items = false
	for art_id in inventory_cards:
		var refs: Dictionary = inventory_cards[art_id]
		var card_panel: PanelContainer = refs["card_panel"]
		var title_lbl: Label = refs["title_label"]
		var config: ArtifactData = art_mgr.artifact_configs[art_id]
		var cnt = int(art_mgr.artifact_inventory.get(art_id, 0))
		
		if cnt > 0:
			has_items = true
			card_panel.visible = true
			title_lbl.text = "%s (x%d)" % [config.name if config.name != "" else art_id, cnt]
		else:
			card_panel.visible = false
			
	empty_inventory_label.visible = not has_items

func _on_artifact_crafted(_id: String, _cnt: int) -> void: update_panel()
func _on_artifact_equipped(_idx: int, _id: String) -> void: update_panel()
func _on_artifact_unequipped(_idx: int, _id: String) -> void: update_panel()
