extends PanelContainer
class_name ShopPanel

## Modal UI Panel displaying the global Upgrades Shop.

signal closed

const EconomyManager = preload("res://scripts/core/economy_manager.gd")

var economy: EconomyManager
var upgrade_cards: Dictionary = {} # upgrade_id -> Dictionary of node refs

func setup(p_economy: EconomyManager) -> void:
	economy = p_economy
	_create_ui()
	update_shop()
	
	if is_instance_valid(economy):
		economy.upgrade_purchased.connect(_on_upgrade_purchased)

func _create_ui() -> void:
	custom_minimum_size = Vector2(450, 400)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.1, 0.14, 0.96)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0.3, 0.6, 1.0, 0.8)
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
	main_vbox.add_theme_constant_override("separation", 14)
	margin.add_child(main_vbox)
	
	# Header HBox
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)
	
	var title_label = Label.new()
	title_label.text = "🛒 Global Upgrades Shop"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
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
	
	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 2)
	sep.color = Color(0.3, 0.6, 1.0, 0.4)
	main_vbox.add_child(sep)
	
	# Scrollable container for upgrades
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)
	
	var cards_vbox = VBoxContainer.new()
	cards_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(cards_vbox)
	
	# Create cards for each upgrade
	for up_id in EconomyManager.UPGRADE_CONFIGS:
		_create_upgrade_card(cards_vbox, up_id)

func _create_upgrade_card(container: Control, up_id: String) -> void:
	var config: Dictionary = EconomyManager.UPGRADE_CONFIGS[up_id]
	
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 80)
	
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.15, 0.2, 0.9)
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.2, 0.4, 0.6, 0.6)
	card_style.corner_radius_top_left = 6
	card_style.corner_radius_top_right = 6
	card_style.corner_radius_bottom_left = 6
	card_style.corner_radius_bottom_right = 6
	card.add_theme_stylebox_override("panel", card_style)
	
	var c_margin = MarginContainer.new()
	c_margin.add_theme_constant_override("margin_left", 10)
	c_margin.add_theme_constant_override("margin_right", 10)
	c_margin.add_theme_constant_override("margin_top", 8)
	c_margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(c_margin)
	
	var c_hbox = HBoxContainer.new()
	c_hbox.add_theme_constant_override("separation", 10)
	c_margin.add_child(c_hbox)
	
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	c_hbox.add_child(info_vbox)
	
	var name_lbl = Label.new()
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	info_vbox.add_child(name_lbl)
	
	var desc_lbl = Label.new()
	desc_lbl.text = config.get("description", "")
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	info_vbox.add_child(desc_lbl)
	
	var bonus_lbl = Label.new()
	bonus_lbl.add_theme_font_size_override("font_size", 10)
	bonus_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	info_vbox.add_child(bonus_lbl)
	
	var buy_btn = Button.new()
	buy_btn.custom_minimum_size = Vector2(110, 0)
	buy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy_btn.pressed.connect(func():
		if is_instance_valid(economy):
			economy.buy_upgrade(up_id)
			update_shop()
	)
	c_hbox.add_child(buy_btn)
	
	container.add_child(card)
	upgrade_cards[up_id] = {
		"name_label": name_lbl,
		"bonus_label": bonus_lbl,
		"buy_button": buy_btn
	}

## Updates all upgrade card labels, levels, and button states.
func update_shop() -> void:
	if economy == null:
		return
		
	for up_id in upgrade_cards:
		var refs: Dictionary = upgrade_cards[up_id]
		var config: Dictionary = EconomyManager.UPGRADE_CONFIGS[up_id]
		var lvl = economy.get_upgrade_level(up_id)
		var max_lvl = int(config.get("max_level", 10))
		var bonus_pct = economy.get_upgrade_bonus(up_id) * 100.0
		
		var name_lbl: Label = refs["name_label"]
		var bonus_lbl: Label = refs["bonus_label"]
		var buy_btn: Button = refs["buy_button"]
		
		name_lbl.text = "%s (Lvl %d/%d)" % [config.get("name", up_id), lvl, max_lvl]
		bonus_lbl.text = "Current Bonus: +%.0f%%" % bonus_pct
		
		if lvl >= max_lvl:
			buy_btn.text = "MAX LEVEL"
			buy_btn.disabled = true
		else:
			var cost = economy.get_upgrade_cost(up_id)
			var cost_val = cost.get("credits", 0.0)
			buy_btn.text = "Lvl %d ($%.1f)" % [lvl + 1, cost_val]
			buy_btn.disabled = not economy.can_afford_upgrade(up_id)

func _on_upgrade_purchased(_up_id: String, _level: int) -> void:
	update_shop()
