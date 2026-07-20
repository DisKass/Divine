extends PanelContainer
class_name ArtifactsPanel

## Modal UI Panel displaying global Artifact Inventory and Equipment Slots.

signal closed

const EconomyManager = preload("res://scripts/core/economy_manager.gd")

var economy: EconomyManager
var slot_cards: Array[Dictionary] = [] # 2 slots UI refs
var inventory_cards: Dictionary = {} # art_id -> Dictionary of node refs
var inventory_container: Control
var empty_inventory_label: Label
var summary_label: Label

func setup(p_economy: EconomyManager) -> void:
	economy = p_economy
	_create_ui()
	update_panel()
	
	if is_instance_valid(economy):
		economy.artifact_crafted.connect(func(_id, _cnt): update_panel())
		economy.artifact_equipped.connect(func(_idx, _id): update_panel())
		economy.artifact_unequipped.connect(func(_idx, _id): update_panel())

func _create_ui() -> void:
	# Clear any previous children if setup called multiple times
	for child in get_children():
		child.queue_free()
		
	custom_minimum_size = Vector2(480, 420)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.1, 0.14, 0.96)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0.9, 0.7, 0.2, 0.8)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.shadow_color = Color(0, 0, 0, 0.5)
	panel_style.shadow_size = 12
	add_theme_stylebox_override("panel", panel_style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(main_vbox)
	
	# Header HBox
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)
	
	var title_label = Label.new()
	title_label.text = "💍 Artifacts & Equipment"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	title_label.add_theme_constant_override("outline_size", 4)
	header_hbox.add_child(title_label)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)
	
	var close_btn = Button.new()
	close_btn.text = " ✕ "
	close_btn.pressed.connect(func():
		visible = false
		closed.emit()
	)
	header_hbox.add_child(close_btn)
	
	var sep1 = ColorRect.new()
	sep1.custom_minimum_size = Vector2(0, 2)
	sep1.color = Color(0.9, 0.7, 0.2, 0.4)
	main_vbox.add_child(sep1)
	
	# Section 1: Equipped Slots
	var eq_title = Label.new()
	eq_title.text = "Active Equipment Slots (Max 2)"
	eq_title.add_theme_font_size_override("font_size", 12)
	eq_title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	main_vbox.add_child(eq_title)
	
	var slots_hbox = HBoxContainer.new()
	slots_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(slots_hbox)
	
	slot_cards.clear()
	for i in range(2):
		_create_slot_card(slots_hbox, i)
		
	# Active Modifiers Summary
	summary_label = Label.new()
	summary_label.text = "Active Modifiers: None"
	summary_label.add_theme_font_size_override("font_size", 11)
	summary_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	main_vbox.add_child(summary_label)
	
	var sep2 = ColorRect.new()
	sep2.custom_minimum_size = Vector2(0, 1)
	sep2.color = Color(0.5, 0.5, 0.5, 0.4)
	main_vbox.add_child(sep2)
	
	# Section 2: Global Inventory
	var inv_title = Label.new()
	inv_title.text = "Artifact Inventory"
	inv_title.add_theme_font_size_override("font_size", 12)
	inv_title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	main_vbox.add_child(inv_title)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)
	
	inventory_container = VBoxContainer.new()
	inventory_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_container.add_theme_constant_override("separation", 8)
	scroll.add_child(inventory_container)
	
	empty_inventory_label = Label.new()
	empty_inventory_label.text = "No artifacts in inventory. Craft them at an Artifact Altar (Tier 3)."
	empty_inventory_label.add_theme_font_size_override("font_size", 10)
	empty_inventory_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	inventory_container.add_child(empty_inventory_label)
	
	inventory_cards.clear()
	for art_id in EconomyManager.ARTIFACT_CONFIGS:
		_create_inventory_item_card(inventory_container, art_id)

func _create_slot_card(container: Control, slot_idx: int) -> void:
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
		if is_instance_valid(economy):
			economy.unequip_artifact(slot_idx)
			update_panel()
	)
	hbox.add_child(unequip_btn)
	
	container.add_child(slot_panel)
	slot_cards.append({
		"title_label": title_lbl,
		"desc_label": desc_lbl,
		"unequip_button": unequip_btn
	})

func _create_inventory_item_card(container: Control, art_id: String) -> void:
	var config: Dictionary = EconomyManager.ARTIFACT_CONFIGS[art_id]
	
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 56)
	card.visible = false # Hidden until inventory count > 0
	
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
	desc_lbl.text = config.get("description", "")
	desc_lbl.add_theme_font_size_override("font_size", 9)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	vbox.add_child(desc_lbl)
	
	var equip_btn = Button.new()
	equip_btn.text = "Equip"
	equip_btn.custom_minimum_size = Vector2(65, 0)
	equip_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	equip_btn.pressed.connect(func():
		if is_instance_valid(economy):
			economy.equip_artifact(art_id)
			update_panel()
	)

	hbox.add_child(equip_btn)
	
	container.add_child(card)
	inventory_cards[art_id] = {
		"card_panel": card,
		"title_label": title_lbl,
		"equip_button": equip_btn
	}

## Updates equipment slots, summary labels, and inventory list state without re-creating nodes.
func update_panel() -> void:
	if economy == null:
		return
		
	# 1. Update Equipment Slots
	for i in range(2):
		var refs: Dictionary = slot_cards[i]
		var art_id = economy.equipped_artifacts[i] if i < economy.equipped_artifacts.size() else ""
		var title_lbl: Label = refs["title_label"]
		var desc_lbl: Label = refs["desc_label"]
		var unequip_btn: Button = refs["unequip_button"]
		
		if art_id != "" and EconomyManager.ARTIFACT_CONFIGS.has(art_id):
			var config: Dictionary = EconomyManager.ARTIFACT_CONFIGS[art_id]
			title_lbl.text = "Slot %d: %s" % [i + 1, config.get("name", art_id)]
			desc_lbl.text = config.get("description", "")
			unequip_btn.visible = true
		else:
			title_lbl.text = "Slot %d: [ Empty ]" % [i + 1]
			desc_lbl.text = "Equip an artifact from inventory"
			unequip_btn.visible = false
			
	# 2. Update Active Modifiers Summary
	var summary_parts: Array[String] = []
	var f_bonus = economy.get_equipped_modifier_bonus("factory_speed")
	if f_bonus > 0: summary_parts.append("+%.0f%% Factory Speed" % (f_bonus * 100.0))
	var m_bonus = economy.get_equipped_modifier_bonus("miner_speed")
	if m_bonus > 0: summary_parts.append("+%.0f%% Mining Speed" % (m_bonus * 100.0))
	var l_bonus = economy.get_equipped_modifier_bonus("logistics_transfer")
	if l_bonus > 0: summary_parts.append("+%.0f%% Logistics" % (l_bonus * 100.0))
	var s_bonus = economy.get_equipped_modifier_bonus("sell_price_mult")
	if s_bonus > 0: summary_parts.append("+%.0f%% Sell Income" % (s_bonus * 100.0))
	
	if summary_parts.is_empty():
		summary_label.text = "Active Modifiers: None"
	else:
		summary_label.text = "Active Modifiers: " + ", ".join(summary_parts)
		
	# 3. Update Inventory Cards state without re-creating nodes
	var has_items = false
	for art_id in inventory_cards:
		var refs: Dictionary = inventory_cards[art_id]
		var card_panel: PanelContainer = refs["card_panel"]
		var title_lbl: Label = refs["title_label"]
		var config: Dictionary = EconomyManager.ARTIFACT_CONFIGS[art_id]
		var cnt = int(economy.artifact_inventory.get(art_id, 0))
		
		if cnt > 0:
			has_items = true
			card_panel.visible = true
			title_lbl.text = "%s (x%d)" % [config.get("name", art_id), cnt]
		else:
			card_panel.visible = false
			
	empty_inventory_label.visible = not has_items

