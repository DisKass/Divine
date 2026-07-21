extends SceneTree

func _init() -> void:
	print("\n==================================================")
	print("Starting Test: GD Panel Reset Functions")
	print("==================================================\n")
	
	test_resets()
	quit(0)

func test_resets() -> void:
	var res_mgr = ResourceManager.new()
	var mod_mgr = ModifierManager.new()
	var ms_mgr = MilestonesManager.new()
	var upg_mgr = UpgradesManager.new(res_mgr, mod_mgr)
	
	res_mgr.add_resource("credits", 1000.0)
	
	# 1. Test Upgrades purchasing and reset
	assert(upg_mgr.buy_upgrade("miner_speed") == true, "Should buy upgrade")
	assert(upg_mgr.get_upgrade_level("miner_speed") == 1, "Level should be 1")
	assert(mod_mgr.get_bonus("miner_speed") > 0.0, "Bonus should be active")
	
	upg_mgr.reset_upgrades()
	assert(upg_mgr.get_upgrade_level("miner_speed") == 0, "Level should reset to 0")
	assert(mod_mgr.get_bonus("miner_speed") == 0.0, "Bonus should clear to 0.0")
	print("[PASS] Upgrades reset verified successfully.")
	
	# 2. Test Milestones submission and reset
	ms_mgr.submit_portal_resource("iron_plate", 10.0)
	var status1 = ms_mgr.get_current_milestone()
	assert(status1.progress.get("iron_plate", 0.0) == 10.0, "Progress should be 10.0")
	
	ms_mgr.reset_milestone_progress()
	var status2 = ms_mgr.get_current_milestone()
	assert(status2.progress.is_empty(), "Progress should be empty")
	assert(status2.tier == 1, "Tier should be 1")
	print("[PASS] Milestone phase reset verified successfully.")
