extends PanelContainer
class_name ShopPanel

## Zone of Responsibility: Modal UI Panel displaying the global Upgrades Shop.

signal closed

@onready var close_btn: Button = $MarginContainer/VBoxContainer/HeaderHBox/CloseBtn
@onready var cards_vbox: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/CardsVBox

var res_mgr: ResourceManager
var upg_mgr: UpgradesManager
var upgrade_cards: Dictionary = {}

func _ready() -> void:
	close_btn.pressed.connect(func():
		visible = false
		closed.emit()
	)

func setup_new(p_res_mgr: ResourceManager, p_upg_mgr: UpgradesManager) -> void:
	res_mgr = p_res_mgr
	upg_mgr = p_upg_mgr
	
	if cards_vbox.get_child_count() == 0:
		_build_cards()
		
	if not upg_mgr.upgrade_purchased.is_connected(_on_upgrade_purchased):
		upg_mgr.upgrade_purchased.connect(_on_upgrade_purchased)
	if not upg_mgr.upgrades_reset.is_connected(update_shop):
		upg_mgr.upgrades_reset.connect(update_shop)

func _build_cards() -> void:
	for up_id in upg_mgr.upgrade_configs:
		var config: UpgradeData = upg_mgr.upgrade_configs[up_id]
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
		desc_lbl.text = config.description
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
			if is_instance_valid(upg_mgr):
				upg_mgr.buy_upgrade(up_id)
				update_shop()
		)
		c_hbox.add_child(buy_btn)
		
		cards_vbox.add_child(card)
		upgrade_cards[up_id] = {
			"name_label": name_lbl,
			"bonus_label": bonus_lbl,
			"buy_button": buy_btn
		}

func update_shop() -> void:
	if upg_mgr == null: return
		
	for up_id in upgrade_cards:
		var refs: Dictionary = upgrade_cards[up_id]
		var config: UpgradeData = upg_mgr.upgrade_configs[up_id]
		var lvl = upg_mgr.get_upgrade_level(up_id)
		var max_lvl = config.max_level
		
		# We must calculate bonus safely from modifier_manager, 
		# but for simplicity, we can also compute it directly since it's just lvl * bonus
		var bonus_pct = lvl * config.bonus_per_level * 100.0
		
		var name_lbl: Label = refs["name_label"]
		var bonus_lbl: Label = refs["bonus_label"]
		var buy_btn: Button = refs["buy_button"]
		
		name_lbl.text = "%s (Lvl %d/%d)" % [config.name if config.name != "" else up_id, lvl, max_lvl]
		bonus_lbl.text = "Current Bonus: +%.0f%%" % bonus_pct
		
		if lvl >= max_lvl:
			buy_btn.text = "MAX LEVEL"
			buy_btn.disabled = true
		else:
			var cost = upg_mgr.get_upgrade_cost(up_id)
			var cost_val = cost.get("credits", 0.0)
			buy_btn.text = "Lvl %d ($%.1f)" % [lvl + 1, cost_val]
			buy_btn.disabled = not upg_mgr.can_afford_upgrade(up_id)

func _on_upgrade_purchased(_up_id: String, _level: int) -> void:
	update_shop()
