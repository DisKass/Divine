extends CanvasLayer
class_name HUD

## UI component managing resources, stats, building purchase cards, and mouse modes.

signal mode_changed(mode: int, build_type: String)
signal reset_game_pressed

const EconomyManager = preload("res://scripts/core/economy_manager.gd")

# HUD elements
var credits_label: Label
var milestone_label: Label
var stats_menu: MenuButton
var shop_panel: ShopPanel
var artifacts_panel: ArtifactsPanel
var tool_buttons: Dictionary = {}

var tool_cost_labels: Dictionary = {}
var _scroll_container: ScrollContainer

# Card scroll state
var _is_scrolling_drag: bool = false
var _scroll_drag_start_pos: Vector2
var _scroll_drag_start_val: int
var _scroll_has_dragged: bool = false

const BUILDING_DESCRIPTIONS: Dictionary = {
	"portal": "Deliver Milestones",
	"miner_iron": "➔ Iron Ore",
	"miner_coal": "➔ Coal",
	"miner_crystal": "➔ Mana Crystal",
	"crusher": "Ore ➔ Dust",
	"smelter": "Ore ➔ Plate/Ingot",
	"constructor": "Plate ➔ Gear",
	"alchemy_lab": "Dust ➔ Essence",
	"artifact_altar": "Ingot ➔ Amulet",
	"seller": "Goods ➔ Credits"
}

func _ready() -> void:
	_create_hud()

func _create_hud() -> void:
	# Top Menu Panel
	var top_panel = PanelContainer.new()
	add_child(top_panel)
	top_panel.custom_minimum_size = Vector2(0, 50)
	top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_bottom = 50
	
	var top_style = StyleBoxFlat.new()
	top_style.bg_color = Color(0.06, 0.08, 0.1, 0.85)
	top_style.border_width_bottom = 2
	top_style.border_color = Color(0.3, 0.6, 1.0, 0.5)
	top_panel.add_theme_stylebox_override("panel", top_style)
	
	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 20)
	top_panel.add_child(top_hbox)
	
	var margin = Control.new()
	margin.custom_minimum_size = Vector2(10, 0)
	top_hbox.add_child(margin)
	
	credits_label = Label.new()
	credits_label.text = "Credits: $0.0"
	credits_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	credits_label.add_theme_font_size_override("font_size", 16)
	credits_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	credits_label.add_theme_color_override("font_outline_color", Color.BLACK)
	credits_label.add_theme_constant_override("outline_size", 4)
	top_hbox.add_child(credits_label)
	
	milestone_label = Label.new()
	milestone_label.text = "Milestone: Tier 1 - Loading..."
	milestone_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	milestone_label.add_theme_font_size_override("font_size", 13)
	milestone_label.add_theme_color_override("font_color", Color(0.95, 0.7, 0.3))
	milestone_label.add_theme_color_override("font_outline_color", Color.BLACK)
	milestone_label.add_theme_constant_override("outline_size", 3)
	top_hbox.add_child(milestone_label)

	stats_menu = MenuButton.new()
	stats_menu.text = "Buildings (0) ▾"
	stats_menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stats_menu.add_theme_font_size_override("font_size", 13)
	stats_menu.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	stats_menu.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	top_hbox.add_child(stats_menu)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer)
	
	var shop_btn = Button.new()
	shop_btn.text = "Upgrades Shop 🛒"
	shop_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shop_btn.pressed.connect(func():
		if is_instance_valid(shop_panel):
			shop_panel.visible = not shop_panel.visible
			if shop_panel.visible:
				shop_panel.update_shop()
	)
	top_hbox.add_child(shop_btn)

	var artifacts_btn = Button.new()
	artifacts_btn.text = "Artifacts 💍"
	artifacts_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	artifacts_btn.pressed.connect(func():
		if is_instance_valid(artifacts_panel):
			artifacts_panel.visible = not artifacts_panel.visible
			if artifacts_panel.visible:
				artifacts_panel.update_panel()
	)
	top_hbox.add_child(artifacts_btn)

	var reset_btn = Button.new()
	reset_btn.text = "Reset Game"
	reset_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reset_btn.pressed.connect(func(): reset_game_pressed.emit())
	top_hbox.add_child(reset_btn)
	
	var top_margin_r = Control.new()
	top_margin_r.custom_minimum_size = Vector2(10, 0)
	top_hbox.add_child(top_margin_r)

	# Setup Panels instances
	var shop_scene = preload("res://scenes/shop_panel.tscn")
	shop_panel = shop_scene.instantiate()
	add_child(shop_panel)
	shop_panel.visible = false

	var art_scene = preload("res://scenes/artifacts_panel.tscn")
	artifacts_panel = art_scene.instantiate()
	add_child(artifacts_panel)
	artifacts_panel.visible = false



	
	# Bottom Toolbar Panel
	var bottom_panel = PanelContainer.new()
	add_child(bottom_panel)
	bottom_panel.custom_minimum_size = Vector2(0, 150)
	bottom_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.offset_top = -150
	bottom_panel.offset_bottom = 0
	
	var bot_style = StyleBoxFlat.new()
	bot_style.bg_color = Color(0.06, 0.08, 0.1, 0.85)
	bot_style.border_width_top = 2
	bot_style.border_color = Color(0.3, 0.6, 1.0, 0.5)
	bottom_panel.add_theme_stylebox_override("panel", bot_style)
	
	var bot_margin = MarginContainer.new()
	bot_margin.add_theme_constant_override("margin_left", 10)
	bot_margin.add_theme_constant_override("margin_right", 10)
	bot_margin.add_theme_constant_override("margin_top", 10)
	bot_margin.add_theme_constant_override("margin_bottom", 10)
	bottom_panel.add_child(bot_margin)
	
	_scroll_container = ScrollContainer.new()
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll_container.mouse_filter = Control.MOUSE_FILTER_PASS
	bot_margin.add_child(_scroll_container)
	_scroll_container.gui_input.connect(func(event): _on_button_gui_input("", event))
	
	var bot_hbox = HBoxContainer.new()
	bot_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	bot_hbox.add_theme_constant_override("separation", 12)
	_scroll_container.add_child(bot_hbox)
	
	# Build buttons (cards)
	var card_types = ["portal", "miner_iron", "miner_coal", "miner_crystal", "crusher", "smelter", "constructor", "alchemy_lab", "artifact_altar", "seller"]
	for b_type in card_types:
		_create_building_card(bot_hbox, b_type)
		
	var vs = VSeparator.new()
	vs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot_hbox.add_child(vs)
	
	_create_building_card(bot_hbox, "demolish")

func _get_accent_color(type: String) -> Color:
	match type:
		"portal":
			return Color(1.0, 0.65, 0.2)
		"miner":
			return Color(0.9, 0.45, 0.1)
		"miner_iron":
			return Color(0.8, 0.5, 0.3)
		"miner_coal":
			return Color(0.3, 0.3, 0.35)
		"miner_crystal":
			return Color(0.7, 0.4, 0.9)
		"crusher":
			return Color(0.5, 0.5, 0.5)
		"smelter":
			return Color(0.95, 0.25, 0.25)
		"constructor":
			return Color(0.2, 0.7, 0.9)
		"alchemy_lab":
			return Color(0.1, 0.8, 0.8)
		"artifact_altar":
			return Color(0.9, 0.8, 0.2)
		"seller":
			return Color(0.2, 0.85, 0.4)
		"demolish":
			return Color(0.95, 0.25, 0.25)
		_:
			return Color(0.7, 0.7, 0.7)

func _create_card_style(accent_color: Color, state: String) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	
	match state:
		"normal":
			style.bg_color = Color(0.08, 0.1, 0.12, 0.95)
			style.border_color = accent_color.darkened(0.3)
			style.shadow_color = Color(0, 0, 0, 0.3)
			style.shadow_size = 4
		"hover":
			style.bg_color = Color(0.12, 0.15, 0.18, 0.95)
			style.border_color = accent_color.lightened(0.1)
			style.shadow_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.15)
			style.shadow_size = 6
		"pressed":
			style.bg_color = Color(0.15, 0.2, 0.25, 0.95)
			style.border_color = Color(1.0, 0.9, 0.3)
			style.shadow_color = Color(1.0, 0.9, 0.3, 0.25)
			style.shadow_size = 8
		"disabled":
			style.bg_color = Color(0.04, 0.05, 0.06, 0.8)
			style.border_color = accent_color.darkened(0.7)
			style.shadow_size = 0
	return style

func _create_building_card(parent_container: Control, b_type: String) -> void:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(120, 110)
	btn.toggle_mode = true
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var color = _get_accent_color(b_type)
	btn.add_theme_stylebox_override("normal", _create_card_style(color, "normal"))
	btn.add_theme_stylebox_override("hover", _create_card_style(color, "hover"))
	btn.add_theme_stylebox_override("pressed", _create_card_style(color, "pressed"))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("disabled", _create_card_style(color, "disabled"))
	
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn.add_child(vbox)
	
	var title_lbl = Label.new()
	if b_type == "demolish":
		title_lbl.text = "Demolish"
	elif b_type.begins_with("miner_"):
		title_lbl.text = b_type.replace("miner_", "").capitalize() + " Miner"
	else:
		title_lbl.text = b_type.capitalize()
		
	title_lbl.add_theme_font_size_override("font_size", 11)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_lbl)
	
	var div = ColorRect.new()
	div.custom_minimum_size = Vector2(0, 2)
	div.color = color
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(div)
	
	var desc_lbl = Label.new()
	if b_type == "demolish":
		desc_lbl.text = "Refund 100%"
	else:
		desc_lbl.text = BUILDING_DESCRIPTIONS.get(b_type, "")
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_lbl)
	
	var price_lbl = Label.new()
	price_lbl.name = "PriceLabel"
	price_lbl.add_theme_font_size_override("font_size", 11)
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if b_type == "demolish":
		price_lbl.text = "Action"
		price_lbl.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3))
	else:
		price_lbl.text = "$0.0"
		price_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(price_lbl)
	
	btn.gui_input.connect(func(event): _on_button_gui_input(b_type, event))
	
	parent_container.add_child(btn)
	tool_buttons[b_type] = btn
	if b_type != "demolish":
		tool_cost_labels[b_type] = price_lbl

func _on_button_gui_input(b_type: String, event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_scrolling_drag = true
				_scroll_drag_start_pos = event.global_position
				_scroll_drag_start_val = _scroll_container.scroll_horizontal
				_scroll_has_dragged = false
			else:
				_is_scrolling_drag = false
				if not _scroll_has_dragged and not b_type.is_empty():
					_on_building_button_pressed(b_type)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_container.scroll_horizontal -= 40
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_container.scroll_horizontal += 40
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _is_scrolling_drag:
		var diff = event.global_position.x - _scroll_drag_start_pos.x
		if abs(diff) > 8:
			_scroll_has_dragged = true
		_scroll_container.scroll_horizontal = _scroll_drag_start_val - int(diff)
		get_viewport().set_input_as_handled()

func _on_building_button_pressed(b_type: String) -> void:
	if b_type == "demolish":
		mode_changed.emit(3, "") # Mode 3 = DEMOLISH
	else:
		mode_changed.emit(1, b_type) # Mode 1 = BUILD

## Main update call to refresh labels, stats, prices and button disable/enabled states.
func update_hud(economy: EconomyManager, credits_per_tick: float, current_mode: int, selected_build_type: String) -> void:
	if is_instance_valid(shop_panel):
		if shop_panel.economy != economy:
			shop_panel.setup(economy)
		if shop_panel.visible:
			shop_panel.update_shop()

	if is_instance_valid(artifacts_panel) and artifacts_panel.economy != economy:
		artifacts_panel.setup(economy)

	# 1. Update resource count & milestone status
	var credits = economy.get_resource("credits")



	credits_label.text = "Credits: $%.1f (+%.1f/s)" % [credits, credits_per_tick]
	
	var m_info = economy.get_current_milestone()
	if m_info.get("completed_all", false):
		milestone_label.text = "Milestone: All Tiers Completed! 🏆"
	else:
		var reqs: Dictionary = m_info.get("requirements", {})
		var prog: Dictionary = m_info.get("progress", {})
		var req_strs: Array[String] = []
		for res in reqs:
			var cur_val = int(prog.get(res, 0.0))
			var target_val = int(reqs[res])
			req_strs.append("%d/%d %s" % [cur_val, target_val, res.replace("_", " ").capitalize()])
		milestone_label.text = "Milestone [Tier %d - %s]: %s" % [
			int(m_info.get("tier", 1)),
			m_info.get("name", ""),
			", ".join(req_strs)
		]
	
	# 2. Update global stats dropdown
	var portals = economy.building_counts.get("portal", 0)
	var miners = economy.building_counts.get("miner", 0) + economy.building_counts.get("miner_iron", 0) + economy.building_counts.get("miner_coal", 0) + economy.building_counts.get("miner_crystal", 0)
	var smelters = economy.building_counts.get("smelter", 0)
	var constructors = economy.building_counts.get("constructor", 0)
	var sellers = economy.building_counts.get("seller", 0)
	var crushers = economy.building_counts.get("crusher", 0)
	var labs = economy.building_counts.get("alchemy_lab", 0)
	var altars = economy.building_counts.get("artifact_altar", 0)
	var total_buildings = portals + miners + crushers + smelters + constructors + labs + altars + sellers
	
	stats_menu.text = "Buildings (%d) ▾" % total_buildings
	
	var popup = stats_menu.get_popup()
	popup.clear()
	popup.add_item("Portal: %d / 1" % portals)
	popup.add_item("Miners: %d" % miners)
	popup.add_item("Crushers: %d" % crushers)
	popup.add_item("Smelters: %d" % smelters)
	popup.add_item("Constructors: %d" % constructors)
	popup.add_item("Labs: %d" % labs)
	popup.add_item("Altars: %d" % altars)
	popup.add_item("Sellers: %d" % sellers)
	for i in range(popup.item_count):
		popup.set_item_disabled(i, true)

	
	# 3. Update toggle states for buttons
	for btn_name in tool_buttons:
		var btn: Button = tool_buttons[btn_name]
		btn.button_pressed = false
		
	var active_btn_name = ""
	if current_mode == 3: # MouseMode.DEMOLISH
		active_btn_name = "demolish"
	elif current_mode == 1: # MouseMode.BUILD
		active_btn_name = selected_build_type
		
	if tool_buttons.has(active_btn_name):
		tool_buttons[active_btn_name].button_pressed = true
		
	# 4. Update prices and disable locked / unaffordable / maxed items
	for b_type in ["portal", "miner_iron", "miner_coal", "miner_crystal", "crusher", "smelter", "constructor", "alchemy_lab", "artifact_altar", "seller"]:
		if tool_buttons.has(b_type):
			var btn: Button = tool_buttons[b_type]
			var is_unlocked = economy.is_building_unlocked(b_type)
			var req_tier = economy.get_building_required_tier(b_type)
			var limit_reached = economy.is_building_limit_reached(b_type)
			var cost = economy.get_building_cost(b_type)
			var price_lbl = tool_cost_labels.get(b_type)
			
			if price_lbl:
				if not is_unlocked:
					price_lbl.text = "Locked (Tier %d)" % req_tier
				elif limit_reached:
					price_lbl.text = "Max Built"
				elif cost.is_empty():
					price_lbl.text = "Free"
				else:
					var cost_val = cost.get("credits", 0.0)
					price_lbl.text = "$%.1f" % cost_val
					
			var is_selected_type = (current_mode == 1 and selected_build_type == b_type)
			if (not is_unlocked or limit_reached or not economy.can_afford(b_type)) and not is_selected_type:
				btn.disabled = true
				if price_lbl:
					if not is_unlocked:
						price_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
					else:
						price_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
			else:
				btn.disabled = false
				if price_lbl:
					price_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))


