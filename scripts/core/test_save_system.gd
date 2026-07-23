extends SceneTree

func _init() -> void:
	print("==================================================")
	print("Starting Test: Save System")
	print("==================================================")
	
	verify_save_system_compatibility()
	quit()

func verify_save_system_compatibility() -> void:
	print("\n--- Verifying Save System Serialization & Backward Compatibility ---")
	var net = FactoryNetwork.new()
	var res_mgr = ResourceManager.new()
	var mod_mgr = ModifierManager.new()
	var ms_mgr = MilestonesManager.new()
	var art_mgr = ArtifactsManager.new(mod_mgr)
	var build_mgr = BuildingManager.new(res_mgr, ms_mgr)
	var upg_mgr = UpgradesManager.new(res_mgr, mod_mgr)
	
	res_mgr.balances["credits"] = 123.4
	upg_mgr.upgrades["miner_speed"] = 3
	art_mgr.artifact_inventory["ring_of_wealth"] = 2
	art_mgr.equip_artifact("ring_of_wealth")
	
	var save_ok = SaveManager.save_game(net, res_mgr, build_mgr, upg_mgr, art_mgr, ms_mgr)
	print("Save Game -> Success: ", save_ok)
	
	var loaded = SaveManager.load_game()
	print("Loaded save format version: ", loaded.get("version", 0))
	
	var restored_upg = UpgradesManager.new(res_mgr, mod_mgr)
	restored_upg.from_dict(loaded.get("upgrades_manager_dict", {}))
	var restored_art = ArtifactsManager.new(mod_mgr)
	restored_art.from_dict(loaded.get("artifacts_manager_dict", {}))
	var restored_res = ResourceManager.new()
	restored_res.from_dict(loaded.get("resource_manager_dict", {}))
	
	var lvl_ok = restored_upg.get_upgrade_level("miner_speed") == 3
	var eq_ok = restored_art.equipped_artifacts[0] == "ring_of_wealth"
	var inv_ok = restored_art.artifact_inventory.get("ring_of_wealth", 0) == 1
	var credits_ok = restored_res.get_resource("credits") == 123.4
	
	# Test Legacy save format
	var legacy_dict = {
		"economy_dict": {
			"resources": { "credits": 50.0 },
			"building_counts": {},
			"current_milestone_index": 0
		}
	}
	var legacy_res = ResourceManager.new()
	legacy_res.from_dict(legacy_dict.get("economy_dict", {}))
	var legacy_safe = legacy_res.get_resource("credits") == 50.0
	print("Legacy Save Fallback Load -> Safe: ", legacy_safe)
	
	if save_ok and loaded.get("version", 0) == 3 and lvl_ok and eq_ok and inv_ok and credits_ok and legacy_safe:
		print("[PASS] Save system versioning, full state serialization, and legacy format migration verified successfully!")
	else:
		print("[FAIL] Save system compatibility verification failed.")
