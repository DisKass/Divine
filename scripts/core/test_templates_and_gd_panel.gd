extends SceneTree

func _init() -> void:
	print("\n==================================================")
	print("Starting Test: Templates & GD Panel Free Build & Reset/Delete")
	print("==================================================\n")
	
	test_free_buildings()
	test_template_manager_and_save_slots()
	quit(0)

func test_free_buildings() -> void:
	print("--- Testing Free Buildings Mode ---")
	var res_mgr = ResourceManager.new()
	var ms_mgr = MilestonesManager.new()
	var build_mgr = BuildingManager.new(res_mgr, ms_mgr)
	
	# Set miner count to 1 so that get_building_cost returns first_paid_costs (credits: 25)
	build_mgr.building_counts["miner"] = 1
	res_mgr.balances["credits"] = 0.0
	assert(build_mgr.can_afford("miner") == false, "Should not afford miner with 0 credits when paid count reached")
	assert(build_mgr.buy_building("miner") == false, "Should not buy miner with 0 credits when paid count reached")
	
	# Enable free building mode
	build_mgr.free_buildings_mode = true
	assert(build_mgr.can_afford("miner") == true, "Should afford miner when free_buildings_mode is true")
	assert(build_mgr.buy_building("miner") == true, "Should buy miner when free_buildings_mode is true")
	assert(build_mgr.building_counts.get("miner", 0) == 2, "Miner count should be 2")
	assert(res_mgr.get_resource("credits") == 0.0, "Credits should remain 0.0")
	
	print("[PASS] Free buildings mode verified successfully.")

func test_template_manager_and_save_slots() -> void:
	print("\n--- Testing TemplateManager & Save System Slots & Reset/Delete ---")
	var net1 = FactoryNetwork.new()
	var res_mgr1 = ResourceManager.new()
	var mod_mgr1 = ModifierManager.new()
	var ms_mgr1 = MilestonesManager.new()
	var art_mgr1 = ArtifactsManager.new(mod_mgr1)
	var build_mgr1 = BuildingManager.new(res_mgr1, ms_mgr1)
	var upg_mgr1 = UpgradesManager.new(res_mgr1, mod_mgr1)
	var tpl_mgr1 = TemplateManager.new()
	
	# Setup Template 1 ("Основной завод")
	res_mgr1.balances["credits"] = 250.0
	net1.add_building("miner", Vector2i(0, 0), {})
	build_mgr1.building_counts["miner"] = 1
	
	# Create Template 2 ("Завод Железа")
	var snap1 = TemplateManager.capture_snapshot(net1, res_mgr1, build_mgr1, upg_mgr1, art_mgr1, ms_mgr1)
	var tpl2_id = tpl_mgr1.create_template("Завод Железа", snap1)
	assert(tpl_mgr1.active_template_id == tpl2_id, "Active template should be tpl2")
	
	# Modify Template 2 state
	res_mgr1.balances["credits"] = 1000.0
	net1.add_building("smelter", Vector2i(5, 5), {})
	build_mgr1.building_counts["smelter"] = 1
	
	# Save to disk
	SaveManager.save_game(net1, res_mgr1, build_mgr1, upg_mgr1, art_mgr1, ms_mgr1, tpl_mgr1)
	
	# Load from disk into fresh instances
	var loaded: Dictionary = SaveManager.load_game()
	var tpl_mgr2 = TemplateManager.new()
	tpl_mgr2.from_dict(loaded.get("template_manager_dict", {}))
	
	assert(tpl_mgr2.templates.size() == 2, "Loaded save should have 2 templates")
	assert(tpl_mgr2.active_template_id == tpl2_id, "Loaded active template should be tpl2")
	
	# Apply active snapshot (Template 2)
	var net2 = FactoryNetwork.new()
	var res_mgr2 = ResourceManager.new()
	var mod_mgr2 = ModifierManager.new()
	var ms_mgr2 = MilestonesManager.new()
	var art_mgr2 = ArtifactsManager.new(mod_mgr2)
	var build_mgr2 = BuildingManager.new(res_mgr2, ms_mgr2)
	var upg_mgr2 = UpgradesManager.new(res_mgr2, mod_mgr2)
	
	var active_snap = tpl_mgr2.templates[tpl2_id]["snapshot"]
	TemplateManager.apply_snapshot(active_snap, net2, res_mgr2, build_mgr2, upg_mgr2, art_mgr2, ms_mgr2)
	
	assert(res_mgr2.get_resource("credits") == 1000.0, "Template 2 credits should be 1000.0")
	assert(net2.buildings.size() == 2, "Template 2 should have 2 buildings")
	
	# Test Reset Active Template (Template 2)
	tpl_mgr2.reset_active_template(net2, res_mgr2, build_mgr2, upg_mgr2, art_mgr2, ms_mgr2)
	assert(res_mgr2.get_resource("credits") == 85.0, "Reset active template should restore default 85.0 credits")
	assert(net2.buildings.size() == 0, "Reset active template should clear buildings")
	print("[PASS] Reset active template verified successfully.")
	
	# Test Delete Active Template (Template 2)
	tpl_mgr2.delete_active_template(net2, res_mgr2, build_mgr2, upg_mgr2, art_mgr2, ms_mgr2)
	assert(tpl_mgr2.templates.size() == 1, "After deleting Template 2, 1 template should remain")
	assert(tpl_mgr2.active_template_id == "tpl_default", "Active template should fall back to tpl_default")
	assert(res_mgr2.get_resource("credits") == 250.0, "Switching to remaining default template should restore 250.0 credits")
	
	# Test Delete the last remaining template (Default)
	tpl_mgr2.delete_active_template(net2, res_mgr2, build_mgr2, upg_mgr2, art_mgr2, ms_mgr2)
	assert(tpl_mgr2.templates.size() == 1, "Deleting sole template must recreate 1 default template")
	assert(tpl_mgr2.get_active_template_name() == "Основной завод", "Recreated sole template name must be 'Основной завод'")
	assert(res_mgr2.get_resource("credits") == 85.0, "Recreated sole template must reset to starting 85.0 credits")
	print("[PASS] Delete template with single template fallback verified successfully.")
