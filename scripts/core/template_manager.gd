class_name TemplateManager
extends RefCounted

## Manages game save profiles / templates for the GD panel.
## Each template stores a full snapshot of the entire game state.

signal template_switched(template_id: String, template_name: String)

var active_template_id: String = "tpl_default"

# template_id (String) -> Dictionary { "id": String, "name": String, "snapshot": Dictionary }
var templates: Dictionary = {}

func _init() -> void:
	_ensure_default_template()

func _ensure_default_template() -> void:
	if not templates.has("tpl_default"):
		templates["tpl_default"] = {
			"id": "tpl_default",
			"name": "Основной завод",
			"snapshot": {}
		}
	if active_template_id == "" or not templates.has(active_template_id):
		active_template_id = "tpl_default"

## Helper to build a dictionary snapshot of all core game managers and network
static func capture_snapshot(network: FactoryNetwork, res_mgr: ResourceManager, build_mgr: BuildingManager, upg_mgr: UpgradesManager, art_mgr: ArtifactsManager, ms_mgr: MilestonesManager) -> Dictionary:
	return {
		"network": network.to_dict() if network else {},
		"resource_manager": res_mgr.to_dict() if res_mgr else {},
		"building_manager": build_mgr.to_dict() if build_mgr else {},
		"upgrades_manager": upg_mgr.to_dict() if upg_mgr else {},
		"artifacts_manager": art_mgr.to_dict() if art_mgr else {},
		"milestones_manager": ms_mgr.to_dict() if ms_mgr else {}
	}

## Helper to apply a dictionary snapshot into existing manager instances
static func apply_snapshot(snapshot: Dictionary, network: FactoryNetwork, res_mgr: ResourceManager, build_mgr: BuildingManager, upg_mgr: UpgradesManager, art_mgr: ArtifactsManager, ms_mgr: MilestonesManager) -> void:
	if snapshot.is_empty():
		return
		
	if network:
		network.load_from_dict(snapshot.get("network", {}))
	if res_mgr:
		res_mgr.from_dict(snapshot.get("resource_manager", {}))
	if build_mgr:
		build_mgr.from_dict(snapshot.get("building_manager", {}))
	if upg_mgr:
		upg_mgr.from_dict(snapshot.get("upgrades_manager", {}))
	if art_mgr:
		art_mgr.from_dict(snapshot.get("artifacts_manager", {}))
	if ms_mgr:
		ms_mgr.from_dict(snapshot.get("milestones_manager", {}))

## Creates a new template from current state, sets it active, and returns its ID.
func create_template(name: String, current_snapshot: Dictionary) -> String:
	# Save current state into active template before switching
	if templates.has(active_template_id) and not current_snapshot.is_empty():
		templates[active_template_id]["snapshot"] = current_snapshot.duplicate(true)
		
	var new_id = "tpl_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000)
	var final_name = name.strip_edges()
	if final_name.is_empty():
		final_name = "Темплейт " + str(templates.size() + 1)
		
	templates[new_id] = {
		"id": new_id,
		"name": final_name,
		"snapshot": current_snapshot.duplicate(true)
	}
	active_template_id = new_id
	var tpl_name = templates[new_id]["name"]
	template_switched.emit(new_id, tpl_name)
	return new_id

## Switches to target template ID. Updates active template snapshot first, then applies target snapshot.
func switch_template(target_id: String, current_snapshot: Dictionary, network: FactoryNetwork, res_mgr: ResourceManager, build_mgr: BuildingManager, upg_mgr: UpgradesManager, art_mgr: ArtifactsManager, ms_mgr: MilestonesManager) -> bool:
	if not templates.has(target_id):
		return false
		
	# 1. Update current template snapshot
	if templates.has(active_template_id) and not current_snapshot.is_empty():
		templates[active_template_id]["snapshot"] = current_snapshot.duplicate(true)
		
	# 2. Switch active ID
	active_template_id = target_id
	
	# 3. Apply target snapshot
	var target_snapshot = templates[target_id].get("snapshot", {})
	if not target_snapshot.is_empty():
		apply_snapshot(target_snapshot, network, res_mgr, build_mgr, upg_mgr, art_mgr, ms_mgr)
		
	var tpl_name = templates[target_id]["name"]
	template_switched.emit(target_id, tpl_name)
	return true

## Resets active template to fresh default state and applies it.
func reset_active_template(network: FactoryNetwork, res_mgr: ResourceManager, build_mgr: BuildingManager, upg_mgr: UpgradesManager, art_mgr: ArtifactsManager, ms_mgr: MilestonesManager) -> void:
	if not templates.has(active_template_id):
		return
		
	var fresh_net = FactoryNetwork.new()
	var fresh_res = ResourceManager.new()
	var fresh_mod = ModifierManager.new()
	var fresh_ms = MilestonesManager.new()
	var fresh_art = ArtifactsManager.new(fresh_mod)
	var fresh_build = BuildingManager.new(fresh_res, fresh_ms)
	var fresh_upg = UpgradesManager.new(fresh_res, fresh_mod)
	
	var fresh_snap = capture_snapshot(fresh_net, fresh_res, fresh_build, fresh_upg, fresh_art, fresh_ms)
	templates[active_template_id]["snapshot"] = fresh_snap
	apply_snapshot(fresh_snap, network, res_mgr, build_mgr, upg_mgr, art_mgr, ms_mgr)
	
	template_switched.emit(active_template_id, get_active_template_name())

## Deletes active template. If it was the only one, creates a fresh "Основной завод" template.
func delete_active_template(network: FactoryNetwork, res_mgr: ResourceManager, build_mgr: BuildingManager, upg_mgr: UpgradesManager, art_mgr: ArtifactsManager, ms_mgr: MilestonesManager) -> void:
	if templates.has(active_template_id):
		templates.erase(active_template_id)
		
	if templates.is_empty():
		_ensure_default_template()
		var fresh_net = FactoryNetwork.new()
		var fresh_res = ResourceManager.new()
		var fresh_mod = ModifierManager.new()
		var fresh_ms = MilestonesManager.new()
		var fresh_art = ArtifactsManager.new(fresh_mod)
		var fresh_build = BuildingManager.new(fresh_res, fresh_ms)
		var fresh_upg = UpgradesManager.new(fresh_res, fresh_mod)
		
		templates["tpl_default"]["snapshot"] = capture_snapshot(fresh_net, fresh_res, fresh_build, fresh_upg, fresh_art, fresh_ms)
		active_template_id = "tpl_default"
	else:
		active_template_id = templates.keys()[0]
		
	var target_snap = templates[active_template_id].get("snapshot", {})
	if not target_snap.is_empty():
		apply_snapshot(target_snap, network, res_mgr, build_mgr, upg_mgr, art_mgr, ms_mgr)
	else:
		var fresh_net = FactoryNetwork.new()
		var fresh_res = ResourceManager.new()
		var fresh_mod = ModifierManager.new()
		var fresh_ms = MilestonesManager.new()
		var fresh_art = ArtifactsManager.new(fresh_mod)
		var fresh_build = BuildingManager.new(fresh_res, fresh_ms)
		var fresh_upg = UpgradesManager.new(fresh_res, fresh_mod)
		apply_snapshot(capture_snapshot(fresh_net, fresh_res, fresh_build, fresh_upg, fresh_art, fresh_ms), network, res_mgr, build_mgr, upg_mgr, art_mgr, ms_mgr)
		
	template_switched.emit(active_template_id, get_active_template_name())

## Update current active template snapshot without switching.
func sync_active_snapshot(snapshot: Dictionary) -> void:
	if templates.has(active_template_id) and not snapshot.is_empty():
		templates[active_template_id]["snapshot"] = snapshot.duplicate(true)

func get_active_template_name() -> String:
	if templates.has(active_template_id):
		return templates[active_template_id].get("name", "Основной завод")
	return "Основной завод"

func to_dict() -> Dictionary:
	return {
		"active_template_id": active_template_id,
		"templates": templates.duplicate(true)
	}

func from_dict(dict: Dictionary) -> void:
	active_template_id = dict.get("active_template_id", "tpl_default")
	templates = dict.get("templates", {}).duplicate(true)
	_ensure_default_template()
