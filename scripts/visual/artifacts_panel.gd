extends PanelContainer
class_name ArtifactsPanel

## Zone of Responsibility: Modal UI Panel displaying global Artifact Inventory and Equipment Slots.

signal closed

@onready var close_btn: Button = $MarginContainer/VBoxContainer/HeaderHBox/CloseBtn
@onready var slots_hbox: HBoxContainer = $MarginContainer/VBoxContainer/SlotsHBox
@onready var summary_label: Label = $MarginContainer/VBoxContainer/SummaryLabel
@onready var inventory_vbox: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/InventoryVBox
@onready var empty_inventory_label: Label = $MarginContainer/VBoxContainer/ScrollContainer/InventoryVBox/EmptyLabel

var state: GameState
var slot_cards: Array[Dictionary] = []
var inventory_cards: Dictionary = {}

func _ready() -> void:
	close_btn.pressed.connect(func():
		visible = false
		closed.emit()
	)

func setup_new(p_state: GameState) -> void:
	if state != null and state.artifact_crafted.is_connected(_on_artifact_crafted):
		state.artifact_crafted.disconnect(_on_artifact_crafted)
		state.artifact_equipped.disconnect(_on_artifact_equipped)
		state.artifact_unequipped.disconnect(_on_artifact_unequipped)
		state.artifacts_changed.disconnect(update_panel)
		
	state = p_state
	
	if state != null and not state.artifact_crafted.is_connected(_on_artifact_crafted):
		state.artifact_crafted.connect(_on_artifact_crafted)
		state.artifact_equipped.connect(_on_artifact_equipped)
		state.artifact_unequipped.connect(_on_artifact_unequipped)
		state.artifacts_changed.connect(update_panel)
	
	if slot_cards.is_empty():
		_build_slots()
		_build_inventory()

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
			ArtifactSystem.unequip_artifact(state, i)
		)
		hbox.add_child(unequip_btn)
		
		slots_hbox.add_child(slot_panel)
		slot_cards.append({
			"title_label": title_lbl,
			"desc_label": desc_lbl,
			"unequip_button": unequip_btn
		})

func _build_inventory() -> void:
	ArtifactSystem.ensure_configs_loaded()
	for a_id in ArtifactSystem.artifact_configs.keys():
		var config: ArtifactData = ArtifactSystem.artifact_configs[a_id]
		
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
			ArtifactSystem.equip_artifact(state, a_id)
		)
		hbox.add_child(equip_btn)
		
		inventory_vbox.add_child(card)
		inventory_cards[a_id] = {
			"card_panel": card,
			"title_label": title_lbl,
			"equip_button": equip_btn
		}

func update_panel() -> void:
	if state == null: return
		
	# Update slots
	for i in range(2):
		var refs: Dictionary = slot_cards[i]
		var item = state.progress.equipped_artifacts[i] if i < state.progress.equipped_artifacts.size() else ""
		var title_lbl: Label = refs["title_label"]
		var desc_lbl: Label = refs["desc_label"]
		var unequip_btn: Button = refs["unequip_button"]
		
		if item != "" and ArtifactSystem.artifact_configs.has(item):
			var config: ArtifactData = ArtifactSystem.artifact_configs[item]
			title_lbl.text = "Slot %d: %s" % [i + 1, config.name if config.name != "" else item]
			desc_lbl.text = config.description
			unequip_btn.visible = true
		else:
			title_lbl.text = "Slot %d: [ Empty ]" % [i + 1]
			desc_lbl.text = "Equip an artifact from inventory"
			unequip_btn.visible = false
			
	# Update Summary
	var summary_parts: Array[String] = []
	var fs_mult = ModifierSystem.get_multiplier(state, "factory_speed") - 1.0
	if fs_mult > 0.001: summary_parts.append("+%.0f%% Factory Speed" % (fs_mult * 100.0))
	var ms_mult = ModifierSystem.get_multiplier(state, "miner_speed") - 1.0
	if ms_mult > 0.001: summary_parts.append("+%.0f%% Mining Speed" % (ms_mult * 100.0))
	var tr_mult = ModifierSystem.get_multiplier(state, "logistics_transfer") - 1.0
	if tr_mult > 0.001: summary_parts.append("+%.0f%% Transfer Speed" % (tr_mult * 100.0))
	
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
		ArtifactSystem.ensure_configs_loaded()
		var config: ArtifactData = ArtifactSystem.artifact_configs[art_id]
		var cnt = state.progress.artifact_inventory.get(art_id, 0)
		
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
