extends SceneTree

func _init() -> void:
	print("==================================================")
	print("Starting Test: Resources and Costs")
	print("==================================================")
	
	verify_economy_rules()
	quit()

func verify_economy_rules() -> void:
	print("\n--- Verifying Economy and Price Scaling ---")
	var res_mgr = ResourceManager.new()
	var ms_mgr = MilestonesManager.new()
	var build_mgr = BuildingManager.new(res_mgr, ms_mgr)
	
	# Initial resource state
	print("Initial credits: ", res_mgr.get_resource("credits"))
	
	# Config validation
	var miner_cost_0 = build_mgr.get_building_cost("miner")
	print("Miner 1 Cost (Count = 0): ", miner_cost_0)
	if miner_cost_0.is_empty():
		print("[PASS] Miner 1 is free.")
	else:
		print("[FAIL] Miner 1 should be free.")
		
	# Buy first miner
	var success = build_mgr.buy_building("miner")
	print("Bought Miner 1. Success: ", success, ", New Credits: ", res_mgr.get_resource("credits"))
	
	# Cost of second miner
	var miner_cost_1 = build_mgr.get_building_cost("miner")
	print("Miner 2 Cost (Count = 1): ", miner_cost_1)
	if miner_cost_1.get("credits", 0.0) == 10.0:
		print("[PASS] Miner 2 costs 10 credits.")
	else:
		print("[FAIL] Miner 2 should cost 10 credits, got: ", miner_cost_1)
		
	# Buy second miner
	success = build_mgr.buy_building("miner")
	print("Bought Miner 2. Success: ", success, ", New Credits: ", res_mgr.get_resource("credits"))
	
	# Cost of third miner
	var miner_cost_2 = build_mgr.get_building_cost("miner")
	print("Miner 3 Cost (Count = 2): ", miner_cost_2)
	# 10.0 * 1.15 = 11.5
	if abs(miner_cost_2.get("credits", 0.0) - 11.5) < 0.01:
		print("[PASS] Miner 3 costs 11.5 credits.")
	else:
		print("[FAIL] Miner 3 should cost 11.5 credits, got: ", miner_cost_2)
		
	# Test refund/demolition
	print("Demolishing Miner 2...")
	build_mgr.refund_building("miner")
	print("Miner Count: ", build_mgr.building_counts.get("miner"), ", Credits: ", res_mgr.get_resource("credits"))
	if res_mgr.get_resource("credits") == 85.0:
		print("[PASS] 100% refund successfully restored credits to 85.0.")
	else:
		print("[FAIL] Refund did not restore correct credits. Expected 85.0, got: ", res_mgr.get_resource("credits"))
