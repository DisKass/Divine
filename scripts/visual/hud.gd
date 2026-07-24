extends CanvasLayer
class_name HUD

## Zone of Responsibility: Managing main overlay UI, input for build tools, and high-level stats display.

signal mode_changed(mode: int, build_type: String)
signal reset_game_pressed

@onready var credits_label: Label = $TopPanel/HBoxContainer/CreditsLabel
@onready var milestone_label: Label = $TopPanel/HBoxContainer/MilestoneLabel
@onready var stats_menu: MenuButton = $TopPanel/HBoxContainer/StatsMenu
@onready var shop_btn: Button = $TopPanel/HBoxContainer/ShopBtn
@onready var artifacts_btn: Button = $TopPanel/HBoxContainer/ArtifactsBtn
@onready var gd_btn: Button = $TopPanel/HBoxContainer/GDBtn
@onready var build_tools_hbox: HBoxContainer = $BottomPanel/MarginContainer/ScrollContainer/BuildToolsHBox
@onready var scroll_container: ScrollContainer = $BottomPanel/MarginContainer/ScrollContainer

var shop_panel: ShopPanel
var artifacts_panel: ArtifactsPanel
var gd_panel: GDPanel
var tool_buttons: Dictionary = {}
var tool_cost_labels: Dictionary = {}

var _is_scrolling_drag: bool = false
var _scroll_drag_start_pos: Vector2
var _scroll_drag_start_val: int
var _scroll_has_dragged: bool = false

const BUILDING_DESCRIPTIONS: Dictionary = {
	"portal": "Deliver Milestones",
	"miner": "Extract Resources",
	"smelter": "Ore ➔ Ingot/Plate",
	"converter": "Plate ➔ Gear/Dust",
	"assembler": "Combine 2 Solids",
	"extractor": "Solid ➔ Essence",
	"infuser": "Solid + Essence",
	"seller": "Goods ➔ Credits",
	"splitter_2": "Split 2 Outputs",
	"splitter_3": "Split 3 Outputs"
}

var fps_label: Label
var _last_visible_count: int = 0
var _last_total_count: int = 0

func update_culling_stats(visible_count: int, total_count: int) -> void:
	_last_visible_count = visible_count
	_last_total_count = total_count

func _ready() -> void:
	# Create real-time FPS counter in top panel
	fps_label = Label.new()
	fps_label.name = "FPSLabel"
	fps_label.add_theme_font_size_override("font_size", 13)
	fps_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	fps_label.add_theme_constant_override("outline_size", 3)
	fps_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var top_hbox = get_node_or_null("TopPanel/HBoxContainer")
	if top_hbox:
		top_hbox.add_child(fps_label)
		top_hbox.move_child(fps_label, 1) # Insert right after Margin1

	# Load panels
	var shop_scene = preload("res://scenes/shop_panel.tscn")
	shop_panel = shop_scene.instantiate()
	add_child(shop_panel)
	shop_panel.visible = false
	
	var art_scene = preload("res://scenes/artifacts_panel.tscn")
	artifacts_panel = art_scene.instantiate()
	add_child(artifacts_panel)
	artifacts_panel.visible = false
	
	shop_btn.pressed.connect(func():
		shop_panel.visible = not shop_panel.visible
		if shop_panel.visible and shop_panel.has_method("update_shop"):
			shop_panel.update_shop()
	)
	
	artifacts_btn.pressed.connect(func():
		artifacts_panel.visible = not artifacts_panel.visible
		if artifacts_panel.visible and artifacts_panel.has_method("update_panel"):
			artifacts_panel.update_panel()
	)
	
	gd_btn.pressed.connect(func():
		if is_instance_valid(gd_panel):
			gd_panel.visible = not gd_panel.visible
	)
	
	scroll_container.gui_input.connect(_on_scroll_gui_input)
	_create_build_buttons()

func _process(_delta: float) -> void:
	if is_instance_valid(fps_label):
		var fps = Engine.get_frames_per_second()
		var culled = max(0, _last_total_count - _last_visible_count)
		if _last_total_count > 0:
			fps_label.text = "FPS: %d | Visible: %d/%d (Culled: %d)" % [fps, _last_visible_count, _last_total_count, culled]
		else:
			fps_label.text = "FPS: %d" % fps
			
		if fps >= 55:
			fps_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
		elif fps >= 30:
			fps_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
		else:
			fps_label.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3))

func _create_build_buttons() -> void:
	var card_types = ["portal", "miner", "smelter", "converter", "assembler", "extractor", "infuser", "seller", "splitter_2", "splitter_3"]
	for b_type in card_types:
		_create_building_card(build_tools_hbox, b_type)
		
	var vs = VSeparator.new()
	vs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_tools_hbox.add_child(vs)
	
	_create_building_card(build_tools_hbox, "demolish")

func _get_accent_color(type: String) -> Color:
	match type:
		"portal": return Color(1.0, 0.65, 0.2)
		"miner": return Color(0.9, 0.45, 0.1)
		"smelter": return Color(0.95, 0.25, 0.25)
		"converter": return Color(0.2, 0.8, 0.5)
		"assembler": return Color(0.3, 0.5, 0.95)
		"extractor": return Color(0.85, 0.35, 0.85)
		"infuser": return Color(0.9, 0.5, 0.9)
		"seller": return Color(0.2, 0.85, 0.4)
		"splitter_2", "splitter_3": return Color(0.9, 0.9, 0.3)
		"demolish": return Color(0.95, 0.25, 0.25)
		_: return Color(0.7, 0.7, 0.7)

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
	if b_type == "demolish": title_lbl.text = "Demolish"
	elif b_type.begins_with("splitter_"): title_lbl.text = "Splitter (" + b_type.replace("splitter_", "") + ")"
	else: title_lbl.text = b_type.capitalize()
		
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
	desc_lbl.text = "Refund 100%" if b_type == "demolish" else BUILDING_DESCRIPTIONS.get(b_type, "")
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_lbl)
	
	var price_lbl = Label.new()
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

func _on_scroll_gui_input(event: InputEvent) -> void:
	_on_button_gui_input("", event)

func _on_button_gui_input(b_type: String, event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_scrolling_drag = true
				_scroll_drag_start_pos = event.global_position
				_scroll_drag_start_val = scroll_container.scroll_horizontal
				_scroll_has_dragged = false
			else:
				_is_scrolling_drag = false
				if not _scroll_has_dragged and not b_type.is_empty():
					_on_building_button_pressed(b_type)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_container.scroll_horizontal -= 40
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_container.scroll_horizontal += 40
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _is_scrolling_drag:
		var diff = event.global_position.x - _scroll_drag_start_pos.x
		if abs(diff) > 8:
			_scroll_has_dragged = true
		scroll_container.scroll_horizontal = _scroll_drag_start_val - int(diff)
		get_viewport().set_input_as_handled()

func _on_building_button_pressed(b_type: String) -> void:
	if b_type == "demolish":
		mode_changed.emit(3, "") # Mode 3 = DEMOLISH
	else:
		mode_changed.emit(1, b_type) # Mode 1 = BUILD

func update_hud_new(res_mgr: ResourceManager, build_mgr: BuildingManager, upg_mgr: UpgradesManager, art_mgr: ArtifactsManager, ms_mgr: MilestonesManager, credits_per_tick: float, current_mode: int, selected_build_type: String) -> void:
	if is_instance_valid(shop_panel):
		if not shop_panel.has_method("setup_new") and shop_panel.has_method("setup"):
			pass # waiting for shop panel refactoring
		elif shop_panel.has_method("setup_new"):
			shop_panel.setup_new(res_mgr, upg_mgr)
			if shop_panel.visible:
				shop_panel.update_shop()

	if is_instance_valid(artifacts_panel):
		if artifacts_panel.has_method("setup_new"):
			artifacts_panel.setup_new(art_mgr)

	var credits = res_mgr.get_resource("credits")
	credits_label.text = "Credits: $%.1f (+%.1f/s)" % [credits, credits_per_tick]
	
	var m_info = ms_mgr.get_current_milestone()
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
	
	var total_buildings = 0
	var popup = stats_menu.get_popup()
	popup.clear()
	for type in build_mgr.building_counts:
		var count = build_mgr.building_counts[type]
		if count > 0:
			var display_name = type.capitalize()
			if type.begins_with("splitter_"): display_name = "Splitter (" + type.replace("splitter_", "") + ")"
			popup.add_item("%s: %d" % [display_name, count])
		total_buildings += count
		
	stats_menu.text = "Buildings (%d) ▾" % total_buildings
	if popup.item_count == 0:
		popup.add_item("No buildings")
	
	for btn_name in tool_buttons:
		var btn: Button = tool_buttons[btn_name]
		btn.button_pressed = false
		
	var active_btn_name = ""
	if current_mode == 3: # DEMOLISH
		active_btn_name = "demolish"
	elif current_mode == 1: # BUILD
		active_btn_name = selected_build_type
		
	if tool_buttons.has(active_btn_name):
		tool_buttons[active_btn_name].button_pressed = true
		
	var card_types = ["portal", "miner", "smelter", "converter", "assembler", "extractor", "infuser", "seller", "splitter_2", "splitter_3"]
	for b_type in card_types:
		if tool_buttons.has(b_type):
			var btn: Button = tool_buttons[b_type]
			var is_unlocked = build_mgr.is_building_unlocked(b_type)
			var req_tier = build_mgr.get_building_required_tier(b_type)
			var limit_reached = build_mgr.is_building_limit_reached(b_type)
			var cost = build_mgr.get_building_cost(b_type)
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
			if (not is_unlocked or limit_reached or not build_mgr.can_afford(b_type)) and not is_selected_type:
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
