class_name TemplateSystem
extends RefCounted

## Manages game save profiles / templates for the GD panel.
## Each template stores a full snapshot of the entire game state (excluding meta data).

static func ensure_default_template(state: GameState) -> void:
	if not state.templates.has("tpl_default"):
		state.templates["tpl_default"] = {
			"id": "tpl_default",
			"name": "Основной завод",
			"snapshot": {}
		}
	if state.active_template_id == "" or not state.templates.has(state.active_template_id):
		state.active_template_id = "tpl_default"

## Creates a new template from current state, sets it active, and returns its ID.
static func create_template(state: GameState, name: String) -> String:
	ensure_default_template(state)

	# Save current state into active template before switching
	if state.templates.has(state.active_template_id):
		state.templates[state.active_template_id]["snapshot"] = state.to_snapshot()

	var new_id = "tpl_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000)
	var final_name = name.strip_edges()
	if final_name.is_empty():
		final_name = "Темплейт " + str(state.templates.size() + 1)

	state.templates[new_id] = {
		"id": new_id,
		"name": final_name,
		"snapshot": state.to_snapshot()
	}
	state.active_template_id = new_id
	var tpl_name = state.templates[new_id]["name"]
	state.template_switched.emit(new_id, tpl_name)
	return new_id

## Switches to target template ID. Updates active template snapshot first, then applies target snapshot.
static func switch_template(state: GameState, target_id: String) -> bool:
	ensure_default_template(state)
	if not state.templates.has(target_id):
		return false

	# 1. Update current template snapshot
	if state.templates.has(state.active_template_id):
		state.templates[state.active_template_id]["snapshot"] = state.to_snapshot()

	# 2. Switch active ID
	state.active_template_id = target_id

	# 3. Apply target snapshot
	var target_snapshot = state.templates[target_id].get("snapshot", {})
	if not target_snapshot.is_empty():
		state.load_from_snapshot(target_snapshot)
	else:
		# If empty, we should initialize a fresh state, but usually it shouldn't be empty unless new
		var fresh_state = GameState.new()
		ResourceSystem.init_default_balances(fresh_state)
		state.load_from_snapshot(fresh_state.to_snapshot())

	var tpl_name = state.templates[target_id]["name"]
	state.template_switched.emit(target_id, tpl_name)
	return true

## Resets active template to fresh default state and applies it.
static func reset_active_template(state: GameState) -> void:
	ensure_default_template(state)
	if not state.templates.has(state.active_template_id):
		return

	var fresh_state = GameState.new()
	ResourceSystem.init_default_balances(fresh_state)
	var fresh_snap = fresh_state.to_snapshot()

	state.templates[state.active_template_id]["snapshot"] = fresh_snap
	state.load_from_snapshot(fresh_snap)

	state.template_switched.emit(state.active_template_id, get_active_template_name(state))

static func delete_active_template(state: GameState) -> void:
	ensure_default_template(state)
	if state.templates.has(state.active_template_id):
		state.templates.erase(state.active_template_id)

	ensure_default_template(state)

	if state.templates[state.active_template_id]["snapshot"].is_empty():
		reset_active_template(state)
	else:
		state.load_from_snapshot(state.templates[state.active_template_id]["snapshot"])
		state.template_switched.emit(state.active_template_id, state.templates[state.active_template_id]["name"])

static func get_active_template_name(state: GameState) -> String:
	ensure_default_template(state)
	if state.templates.has(state.active_template_id):
		return state.templates[state.active_template_id]["name"]
	return "Unknown"

static func rename_active_template(state: GameState, new_name: String) -> void:
	ensure_default_template(state)
	if state.templates.has(state.active_template_id):
		var final_name = new_name.strip_edges()
		if not final_name.is_empty():
			state.templates[state.active_template_id]["name"] = final_name
			state.template_switched.emit(state.active_template_id, final_name)

static func sync_active_snapshot(state: GameState) -> void:
	ensure_default_template(state)
	if state.templates.has(state.active_template_id):
		state.templates[state.active_template_id]["snapshot"] = state.to_snapshot()
