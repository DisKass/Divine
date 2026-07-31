extends PanelContainer
class_name GDPanel

## Game Designer / Debug panel for testing, free building mode, and template switching.

var state: GameState
var main_game: MainGame

var close_btn: Button
var free_build_check: CheckBox
var templates_dropdown: OptionButton
var reset_tpl_btn: Button
var delete_tpl_btn: Button
var reset_phase_btn: Button
var reset_upgrades_btn: Button
var reset_game_btn: Button
var content_vbox: VBoxContainer

var create_dialog: ConfirmationDialog
var confirm_delete_dialog: ConfirmationDialog
var dialog_name_edit: LineEdit

func setup(p_state: GameState, p_main_game: MainGame = null) -> void:
	state = p_state
	main_game = p_main_game
	
	_build_ui()
	_setup_dialogs()

func _build_ui() -> void:
	# Clean up previous children if setup called multiple times
	for child in get_children():
		child.queue_free()

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
	
	# 1. CheckBox: Free Buildings Mode
	free_build_check = CheckBox.new()
	free_build_check.text = "🆓 Бесплатная постройка"
	free_build_check.add_theme_font_size_override("font_size", 11)
	if state != null:
		free_build_check.button_pressed = state.free_buildings_mode
	free_build_check.toggled.connect(_on_free_build_toggled)
	content_vbox.add_child(free_build_check)
	
	# Separator
	content_vbox.add_child(HSeparator.new())
	
	# 2. Template Selection Section
	var tpl_lbl = Label.new()
	tpl_lbl.text = "📋 Темплейт завода (сейв-слот):"
	tpl_lbl.add_theme_font_size_override("font_size", 11)
	tpl_lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	content_vbox.add_child(tpl_lbl)
	
	templates_dropdown = OptionButton.new()
	templates_dropdown.custom_minimum_size = Vector2(180, 26)
	templates_dropdown.add_theme_font_size_override("font_size", 11)
	templates_dropdown.item_selected.connect(_on_template_option_selected)
	content_vbox.add_child(templates_dropdown)
	
	# Buttons for Template Actions
	var tpl_btns_hbox = HBoxContainer.new()
	tpl_btns_hbox.add_theme_constant_override("separation", 6)
	content_vbox.add_child(tpl_btns_hbox)
	
	reset_tpl_btn = Button.new()
	reset_tpl_btn.text = "🔄 Сбросить"
	reset_tpl_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_tpl_btn.custom_minimum_size = Vector2(85, 24)
	reset_tpl_btn.add_theme_font_size_override("font_size", 10)
	reset_tpl_btn.pressed.connect(_on_reset_template_pressed)
	tpl_btns_hbox.add_child(reset_tpl_btn)
	
	delete_tpl_btn = Button.new()
	delete_tpl_btn.text = "🗑️ Удалить"
	delete_tpl_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete_tpl_btn.custom_minimum_size = Vector2(85, 24)
	delete_tpl_btn.add_theme_font_size_override("font_size", 10)
	delete_tpl_btn.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	delete_tpl_btn.pressed.connect(_on_delete_template_pressed)
	tpl_btns_hbox.add_child(delete_tpl_btn)
	
	_refresh_templates_dropdown()
	
	# Separator
	content_vbox.add_child(HSeparator.new())
	
	# Button 1: Reset Phase (Milestones)
	reset_phase_btn = Button.new()
	reset_phase_btn.text = "🔄 Сбросить фазу"
	reset_phase_btn.custom_minimum_size = Vector2(180, 26)
	reset_phase_btn.add_theme_font_size_override("font_size", 11)
	reset_phase_btn.pressed.connect(_on_reset_phase_pressed)
	content_vbox.add_child(reset_phase_btn)
	
	# Button 2: Reset Shop Upgrades
	reset_upgrades_btn = Button.new()
	reset_upgrades_btn.text = "🛒 Сбросить апгрейды"
	reset_upgrades_btn.custom_minimum_size = Vector2(180, 26)
	reset_upgrades_btn.add_theme_font_size_override("font_size", 11)
	reset_upgrades_btn.pressed.connect(_on_reset_upgrades_pressed)
	content_vbox.add_child(reset_upgrades_btn)
	
	# Separator
	content_vbox.add_child(HSeparator.new())
	
	# Button 3: Reset Whole Game
	reset_game_btn = Button.new()
	reset_game_btn.text = "⚠️ Сбросить всю игру"
	reset_game_btn.custom_minimum_size = Vector2(180, 26)
	reset_game_btn.add_theme_font_size_override("font_size", 11)
	reset_game_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	reset_game_btn.pressed.connect(_on_reset_game_pressed)
	content_vbox.add_child(reset_game_btn)

func _setup_dialogs() -> void:
	# 1. Dialog for Creating New Template
	create_dialog = ConfirmationDialog.new()
	create_dialog.title = "Создать темплейт завода"
	create_dialog.dialog_hide_on_ok = true
	add_child(create_dialog)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	
	var lbl = Label.new()
	lbl.text = "Введите название для нового темплейта:"
	lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(lbl)
	
	dialog_name_edit = LineEdit.new()
	dialog_name_edit.placeholder_text = "например, Завод Железа"
	dialog_name_edit.custom_minimum_size = Vector2(240, 28)
	vbox.add_child(dialog_name_edit)
	
	create_dialog.add_child(vbox)
	create_dialog.confirmed.connect(_on_create_dialog_confirmed)
	
	# 2. Dialog for Confirming Deletion of Template
	confirm_delete_dialog = ConfirmationDialog.new()
	confirm_delete_dialog.title = "Удаление темплейта"
	confirm_delete_dialog.dialog_text = "Вы уверены, что хотите удалить этот темплейт?"
	confirm_delete_dialog.dialog_hide_on_ok = true
	add_child(confirm_delete_dialog)
	confirm_delete_dialog.confirmed.connect(_on_confirm_delete_dialog_confirmed)

func _refresh_templates_dropdown() -> void:
	if templates_dropdown == null or state == null:
		return
		
	templates_dropdown.clear()
	# Index 0 is always "Create New"
	templates_dropdown.add_item("➕ Создать новый...", 0)
	
	var active_id = state.active_template_id
	var select_idx = 0
	
	var keys = state.templates.keys()
	for i in range(keys.size()):
		var t_id = keys[i]
		var t_data = state.templates[t_id]
		var t_name = t_data.get("name", "Темплейт")
		var idx = i + 1
		templates_dropdown.add_item(t_name, idx)
		templates_dropdown.set_item_metadata(idx, t_id)
		
		if t_id == active_id:
			select_idx = idx
			
	templates_dropdown.select(select_idx)

func _on_free_build_toggled(toggled: bool) -> void:
	if state != null:
		state.free_buildings_mode = toggled

func _on_template_option_selected(idx: int) -> void:
	if idx == 0:
		# Create New Template
		dialog_name_edit.text = "Темплейт " + str(state.templates.size() + 1)
		create_dialog.popup_centered(Vector2i(300, 130))
	else:
		# Switch to selected existing template
		var target_id = templates_dropdown.get_item_metadata(idx)
		if main_game != null and target_id != null:
			main_game.switch_template(target_id)
			_refresh_templates_dropdown()

func _on_create_dialog_confirmed() -> void:
	var t_name = dialog_name_edit.text
	if main_game != null:
		main_game.create_template(t_name)
		_refresh_templates_dropdown()

func _on_reset_template_pressed() -> void:
	if main_game != null:
		main_game.reset_active_template()
		_refresh_templates_dropdown()

func _on_delete_template_pressed() -> void:
	if confirm_delete_dialog != null:
		var active_name = TemplateSystem.get_active_template_name(state) if state != null else ""
		confirm_delete_dialog.dialog_text = "Удалить темплейт '%s'?" % active_name
		confirm_delete_dialog.popup_centered(Vector2i(320, 110))

func _on_confirm_delete_dialog_confirmed() -> void:
	if main_game != null:
		main_game.delete_active_template()
		_refresh_templates_dropdown()

func _on_reset_phase_pressed() -> void:
	if state != null:
		MilestoneSystem.reset_milestone_progress(state)
		if main_game != null and main_game.has_method("_update_ui"):
			main_game.call("_update_ui")
			main_game.call("_update_inspector")

func _on_reset_upgrades_pressed() -> void:
	if state != null:
		UpgradeSystem.reset_upgrades(state)
		if main_game != null and main_game.has_method("_update_ui"):
			main_game.call("_update_ui")

func _on_reset_game_pressed() -> void:
	if main_game != null and main_game.has_method("_on_reset_pressed"):
		main_game.call("_on_reset_pressed")
		_refresh_templates_dropdown()
