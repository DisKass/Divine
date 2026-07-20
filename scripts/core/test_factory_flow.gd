extends SceneTree



func _init() -> void:
	print("==================================================")
	print("Starting Test: Factory Flow")
	print("==================================================")
	
	verify_resource_flow()
	verify_portal_milestones()
	quit()

func verify_resource_flow() -> void:
	print("\n--- Verifying Resource Flow and Production ---")
	var net = FactoryNetwork.new()
	var res_mgr = ResourceManager.new()
	var mod_mgr = ModifierManager.new()
	var ms_mgr = MilestonesManager.new()
	var art_mgr = ArtifactsManager.new(mod_mgr)
	var ticker = SimulationTicker.new(net, res_mgr, mod_mgr, ms_mgr, art_mgr)
	
	res_mgr.balances["credits"] = 0.0
	
	var miner_rec = { "inputs": {}, "outputs": { "iron_ore": 1.0 }, "duration": 1.0 }
	var smelter_rec = { "inputs": { "iron_ore": 1.0 }, "outputs": { "iron_plate": 1.0 }, "duration": 1.0 }
	var seller_rec = { "inputs": { "iron_plate": 1.0 }, "outputs": { "credits": 5.0 }, "duration": 1.0 }
	
	var miner = net.add_building("miner", Vector2i(0, 0), miner_rec)
	var smelter = net.add_building("smelter", Vector2i(0, 1), smelter_rec)
	var seller = net.add_building("seller", Vector2i(0, 2), seller_rec)
	
	net.add_connection(miner.id, smelter.id)
	net.add_connection(smelter.id, seller.id)
	
	net.tick(1.0, res_mgr, mod_mgr, ms_mgr, art_mgr) # miner produces
	net.tick(1.0, res_mgr, mod_mgr, ms_mgr, art_mgr) # moves to smelter, smelter produces
	net.tick(1.0, res_mgr, mod_mgr, ms_mgr, art_mgr) # moves to seller, seller produces
	net.tick(1.0, res_mgr, mod_mgr, ms_mgr, art_mgr) # seller outputs to credits
	
	if res_mgr.get_resource("credits") == 10.0: # (2 cycles finished for seller) -> Wait, tick 3 seller produces, tick 4 harvests. 2 outputs = 10.0
		print("[PASS] Resource flow and global credit harvesting work correctly.")
	else:
		print("[FAIL] Resource flow failed. Expected 10.0 credits, got: ", res_mgr.get_resource("credits"))

func verify_portal_milestones() -> void:
	print("\n--- Verifying Portal Building & Milestone Progression ---")
	var net = FactoryNetwork.new()
	var res_mgr = ResourceManager.new()
	var ms_mgr = MilestonesManager.new()
	var build_mgr = BuildingManager.new(res_mgr, ms_mgr)
	var mod_mgr = ModifierManager.new()
	var art_mgr = ArtifactsManager.new(mod_mgr)
	var ticker = SimulationTicker.new(net, res_mgr, mod_mgr, ms_mgr, art_mgr)
	
	res_mgr.balances["credits"] = 100.0
	
	var buy1 = build_mgr.buy_building("portal")
	var buy2 = build_mgr.buy_building("portal")
	if buy1 and not buy2:
		print("[PASS] Portal max count limit (1) enforced correctly.")
	else:
		print("[FAIL] Portal max count enforcement failed.")
		
	var portal = net.add_building("portal", Vector2i(5, 5), {})
	var plate_producer = net.add_building("constructor", Vector2i(5, 4), {
		"inputs": {},
		"outputs": { "iron_plate": 10.0, "iron_gear": 5.0 },
		"duration": 1.0
	})
	
	net.add_connection(plate_producer.id, portal.id)
	
	var milestone_count = [0]
	ms_mgr.milestone_completed.connect(func(tier, data):
		milestone_count[0] += 1
		print("SIGNAL RECEIVED: Milestone Tier %d (%s) Completed!" % [tier, data["name"]])
	)
	
	for t in range(25):
		net.tick(1.0, res_mgr, mod_mgr, ms_mgr, art_mgr)
	
	var m_status2 = ms_mgr.get_current_milestone()
	if milestone_count[0] >= 1 and int(m_status2.get("tier", 0)) == 2:
		print("[PASS] Portal delivery and Milestone Tier 1 completion verified successfully!")
	else:
		print("[FAIL] Milestone completion failed.")
