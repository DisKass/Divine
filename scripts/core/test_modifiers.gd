extends SceneTree

func _init() -> void:
	print("==================================================")
	print("Starting Test: Modifiers and Upgrades")
	print("==================================================")
	
	verify_upgrades_shop()
	verify_artifact_altar_and_inventory()
	quit()

func verify_upgrades_shop() -> void:
	print("\n--- Verifying Global Upgrades Shop & Logistics Bottleneck ---")
	var res_mgr = ResourceManager.new()
	var mod_mgr = ModifierManager.new()
	var upg_mgr = UpgradesManager.new(res_mgr, mod_mgr)
	var ms_mgr = MilestonesManager.new()
	var art_mgr = ArtifactsManager.new(mod_mgr)
	var build_mgr = BuildingManager.new(res_mgr, ms_mgr)
	
	res_mgr.balances["credits"] = 500.0
	
	print("Initial Credits: ", res_mgr.get_resource("credits"))
	var cost_lvl1 = upg_mgr.get_upgrade_cost("miner_speed")
	print("Miner Speed Lvl 1 Cost: ", cost_lvl1)
	
	var buy1 = upg_mgr.buy_upgrade("miner_speed")
	var buy2 = upg_mgr.buy_upgrade("miner_speed")
	print("Miner Speed Lvl 2 -> Credits Left: ", res_mgr.get_resource("credits"))
	
	var net = FactoryNetwork.new()
	var miner = net.add_building("miner", Vector2i(0, 0), {})
	var smelter = net.add_building("smelter", Vector2i(0, 1), {
		"inputs": { "iron_ore": 1.0 },
		"outputs": { "iron_plate": 1.0 },
		"duration": 1.0
	})
	
	miner.outputs["iron_ore"] = 2.0
	net.add_connection(miner.id, smelter.id)
	
	net.tick(1.0, res_mgr, mod_mgr, ms_mgr, art_mgr) # Internal test tick
	
	var backlog_base = miner.outputs.get("iron_ore", 0.0)
	print("Miner backlog without logistics upgrade (max_transfer=1.0): ", backlog_base)
	
	upg_mgr.buy_upgrade("logistics_transfer")
	upg_mgr.buy_upgrade("logistics_transfer")
	
	miner.outputs["iron_ore"] = 2.0
	smelter.inputs["iron_ore"] = 0.0
	net.tick(1.0, res_mgr, mod_mgr, ms_mgr, art_mgr)
	
	var backlog_upgraded = miner.outputs.get("iron_ore", 0.0)
	print("Miner backlog with Logistics Lvl 2 upgrade (max_transfer=2.0): ", backlog_upgraded)
	
	if buy1 and buy2 and backlog_base == 1.0 and backlog_upgraded == 0.0:
		print("[PASS] Global Upgrades purchasing and bottleneck verified.")
	else:
		print("[FAIL] Global Upgrades verification failed.")

func verify_artifact_altar_and_inventory() -> void:
	print("\n--- Verifying Artifact Altar Crafting & Global Inventory ---")
	var net = FactoryNetwork.new()
	var res_mgr = ResourceManager.new()
	var mod_mgr = ModifierManager.new()
	var ms_mgr = MilestonesManager.new()
	var art_mgr = ArtifactsManager.new(mod_mgr)
	
	var altar = net.add_building("artifact_altar", Vector2i(0, 0), {
		"inputs": {},
		"outputs": { "runesteel_amulet": 1.0 },
		"duration": 1.0
	})
	
	net.tick(1.0, res_mgr, mod_mgr, ms_mgr, art_mgr)
	
	var inv_before = int(art_mgr.artifact_inventory.get("runesteel_amulet", 0))
	var equip_ok = art_mgr.equip_artifact("runesteel_amulet")
	var inv_after = int(art_mgr.artifact_inventory.get("runesteel_amulet", 0))
	
	var factory_mod = mod_mgr.get_multiplier("factory_speed")
	var logistics_mod = mod_mgr.get_multiplier("logistics_transfer")
	
	if inv_before == 1 and inv_after == 0 and equip_ok and factory_mod > 1.0:
		print("[PASS] Artifact Crafting and Modifiers verified.")
	else:
		print("[FAIL] Artifact verification failed.")
