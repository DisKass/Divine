extends PanelContainer
class_name GDPanel

## Game Designer / Debug panel for testing and quick state resets.

var milestones_mgr: MilestonesManager
var upgrades_mgr: UpgradesManager
var main_game: MainGame

var is_collapsed: bool = false

var close_btn: Button
var reset_phase_btn: Button
var reset_upgrades_btn: Button
var reset_game_btn: Button
var content_vbox: VBoxContainer

func setup(p_ms_mgr: MilestonesManager, p_upg_mgr: UpgradesManager, p_main_game: MainGame = null) -> void:
	milestones_mgr = p_ms_mgr
	upgrades_mgr = p_upg_mgr
	main_game = p_main_game
	
	_build_ui()

func _build_ui() -> void:
	# Panel Styling
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.12, 0.18, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.3, 0.5, 0.8, 0.8)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.shadow_size = 8
	panel_style.shadow_color = Color(0, 0, 0, 0.5)
	add_theme_stylebox_override("panel", panel_style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	
	var outer_vbox = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(outer_vbox)
	
	# Header HBox
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 10)
	outer_vbox.add_child(header_hbox)
	
	var title_lbl = Label.new()
	title_lbl.text = "🛠 Панель Геймдизайнера"
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_lbl)
	
	close_btn = Button.new()
	close_btn.text = " ✕ "
	close_btn.flat = true
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.pressed.connect(func(): visible = false)
	header_hbox.add_child(close_btn)
	
	# Content VBox
	content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 8)
	outer_vbox.add_child(content_vbox)
	
	# Button 1: Reset Phase (Milestones)
	reset_phase_btn = Button.new()
	reset_phase_btn.text = "🔄 Сбросить фазу"
	reset_phase_btn.custom_minimum_size = Vector2(180, 28)
	reset_phase_btn.add_theme_font_size_override("font_size", 11)
	reset_phase_btn.pressed.connect(_on_reset_phase_pressed)
	content_vbox.add_child(reset_phase_btn)
	
	# Button 2: Reset Shop Upgrades
	reset_upgrades_btn = Button.new()
	reset_upgrades_btn.text = "🛒 Сбросить апгрейды"
	reset_upgrades_btn.custom_minimum_size = Vector2(180, 28)
	reset_upgrades_btn.add_theme_font_size_override("font_size", 11)
	reset_upgrades_btn.pressed.connect(_on_reset_upgrades_pressed)
	content_vbox.add_child(reset_upgrades_btn)
	
	# Separator
	var hsep = HSeparator.new()
	content_vbox.add_child(hsep)
	
	# Button 3: Reset Whole Game
	reset_game_btn = Button.new()
	reset_game_btn.text = "⚠️ Сбросить всю игру"
	reset_game_btn.custom_minimum_size = Vector2(180, 28)
	reset_game_btn.add_theme_font_size_override("font_size", 11)
	reset_game_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	reset_game_btn.pressed.connect(_on_reset_game_pressed)
	content_vbox.add_child(reset_game_btn)

func _on_reset_phase_pressed() -> void:
	if milestones_mgr != null:
		milestones_mgr.reset_milestone_progress()
		if main_game != null and main_game.has_method("_update_ui"):
			main_game.call("_update_ui")
			main_game.call("_update_inspector")

func _on_reset_upgrades_pressed() -> void:
	if upgrades_mgr != null:
		upgrades_mgr.reset_upgrades()
		if main_game != null and main_game.has_method("_update_ui"):
			main_game.call("_update_ui")

func _on_reset_game_pressed() -> void:
	if main_game != null and main_game.has_method("_on_reset_pressed"):
		main_game.call("_on_reset_pressed")
