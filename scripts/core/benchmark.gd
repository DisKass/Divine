extends SceneTree

const Recipes = preload("res://scripts/core/recipes.gd")

func _init() -> void:
	print("==================================================")
	print("Starting Factory Simulation Benchmark & Verification")
	print("==================================================")
	
	verify_economy_rules()
	verify_resource_flow()
	verify_multi_recipe_switching()
	run_performance_benchmark()
	
	quit()

func verify_economy_rules() -> void:
	print("\n--- Verifying Economy and Price Scaling ---")
	var economy = EconomyManager.new()
	
	# Initial resource state
	print("Initial credits: ", economy.get_resource("credits"))
	
	# Config validation
	var miner_cost_0 = economy.get_building_cost("miner")
	print("Miner 1 Cost (Count = 0): ", miner_cost_0)
	if miner_cost_0.is_empty():
		print("[PASS] Miner 1 is free.")
	else:
		print("[FAIL] Miner 1 should be free.")
		
	# Buy first miner
	var success = economy.buy_building("miner")
	print("Bought Miner 1. Success: ", success, ", New Credits: ", economy.get_resource("credits"))
	
	# Cost of second miner
	var miner_cost_1 = economy.get_building_cost("miner")
	print("Miner 2 Cost (Count = 1): ", miner_cost_1)
	if miner_cost_1.get("credits", 0.0) == 10.0:
		print("[PASS] Miner 2 costs 10 credits.")
	else:
		print("[FAIL] Miner 2 should cost 10 credits, got: ", miner_cost_1)
		
	# Buy second miner
	success = economy.buy_building("miner")
	print("Bought Miner 2. Success: ", success, ", New Credits: ", economy.get_resource("credits"))
	
	# Cost of third miner
	var miner_cost_2 = economy.get_building_cost("miner")
	print("Miner 3 Cost (Count = 2): ", miner_cost_2)
	# 10.0 * 1.15 = 11.5
	if abs(miner_cost_2.get("credits", 0.0) - 11.5) < 0.01:
		print("[PASS] Miner 3 costs 11.5 credits.")
	else:
		print("[FAIL] Miner 3 should cost 11.5 credits, got: ", miner_cost_2)
		
	# Test refund/demolition
	print("Demolishing Miner 2...")
	economy.refund_building("miner")
	print("Miner Count: ", economy.building_counts.get("miner"), ", Credits: ", economy.get_resource("credits"))
	if economy.get_resource("credits") == 85.0:
		print("[PASS] 100% refund successfully restored credits to 85.0.")
	else:
		print("[FAIL] Refund did not restore correct credits. Expected 85.0, got: ", economy.get_resource("credits"))

func verify_resource_flow() -> void:
	print("\n--- Verifying Resource Flow and Production ---")
	var net = FactoryNetwork.new()
	var economy = EconomyManager.new()
	economy.resources["credits"] = 0.0 # reset for test
	
	# Define recipes
	var miner_rec = {
		"inputs": {},
		"outputs": { "iron_ore": 1.0 },
		"duration": 1.0
	}
	var smelter_rec = {
		"inputs": { "iron_ore": 1.0 },
		"outputs": { "iron_plate": 1.0 },
		"duration": 1.0
	}
	var seller_rec = {
		"inputs": { "iron_plate": 1.0 },
		"outputs": { "credits": 5.0 },
		"duration": 1.0
	}
	
	# Spawn buildings
	var miner = net.add_building("miner", Vector2i(0, 0), miner_rec)
	var smelter = net.add_building("smelter", Vector2i(0, 1), smelter_rec)
	var seller = net.add_building("seller", Vector2i(0, 2), seller_rec)
	
	# Connect them Miner -> Smelter -> Seller
	net.add_connection(miner.id, smelter.id)
	net.add_connection(smelter.id, seller.id)
	
	print("Factory setup complete. Running simulation ticks...")
	
	# Tick 1
	# Miner starts producing iron_ore
	net.tick(1.0, economy)
	print("Tick 1: Miner output iron_ore: ", miner.outputs.get("iron_ore"))
	
	# Tick 2
	# Ore transfers from miner outputs to smelter inputs. Miner starts producing again.
	# Smelter starts producing iron_plate since it received input.
	net.tick(1.0, economy)
	print("Tick 2: Miner output iron_ore: ", miner.outputs.get("iron_ore"), ", Smelter input iron_ore: ", smelter.inputs.get("iron_ore"))
	print("        Smelter output iron_plate: ", smelter.outputs.get("iron_plate"))
	
	# Tick 3
	# Iron plate transfers from smelter to seller.
	# Seller starts producing credits.
	net.tick(1.0, economy)
	print("Tick 3: Seller input iron_plate: ", seller.inputs.get("iron_plate"))
	print("        Economy Credits: ", economy.get_resource("credits"))
	
	# Tick 4
	# Seller completes credits production, credits harvested.
	net.tick(1.0, economy)
	print("Tick 4: Economy Credits: ", economy.get_resource("credits"))
	
	if economy.get_resource("credits") == 10.0:
		print("[PASS] Resource flow and global credit harvesting work correctly.")
	else:
		print("[FAIL] Resource flow or harvesting failed. Expected 10.0 credits, got: ", economy.get_resource("credits"))

func verify_multi_recipe_switching() -> void:
	print("\n--- Verifying Multi-Recipe Switching ---")
	var net = FactoryNetwork.new()
	var economy = EconomyManager.new()
	
	# Create a smelter
	var initial_recipe = Recipes.DATA["smelter"][0] # Smelt Iron Plate
	var smelter = net.add_building("smelter", Vector2i(0, 0), initial_recipe)
	
	# Verify initial recipe is "smelt_plate"
	print("Initial Smelter Recipe ID: ", smelter.active_recipe.get("id"))
	if smelter.active_recipe.get("id") == "smelt_plate":
		print("[PASS] Initial recipe matches smelt_plate.")
	else:
		print("[FAIL] Initial recipe should be smelt_plate.")
		
	# Put some inputs and progress production
	smelter.inputs["iron_ore"] = 1.0
	net.tick(0.5, economy)
	print("Smelter is producing: ", smelter.is_producing, ", progress: ", smelter.production_progress)
	
	# Switch recipe to "smelt_ingot"
	var new_recipe = Recipes.DATA["smelter"][1] # Smelt Iron Ingot
	smelter.set_recipe(new_recipe)
	print("Switched Smelter Recipe ID: ", smelter.active_recipe.get("id"))
	
	# Verify that buffers and production state were reset
	print("Is producing after switch: ", smelter.is_producing, ", progress: ", smelter.production_progress)
	print("Inputs after switch: ", smelter.inputs)
	if smelter.active_recipe.get("id") == "smelt_ingot" and not smelter.is_producing and smelter.inputs.get("iron_ore", 0.0) == 0.0:
		print("[PASS] Recipe switch successfully reset state and buffers.")
	else:
		print("[FAIL] Recipe switch did not reset state and buffers correctly.")

func run_performance_benchmark() -> void:
	print("\n--- Running Performance Benchmark (2,000 Buildings) ---")
	var net = FactoryNetwork.new()
	var economy = EconomyManager.new()
	
	# Define recipes
	var miner_rec = { "inputs": {}, "outputs": { "iron_ore": 1.0 }, "duration": 1.0 }
	var smelter_rec = { "inputs": { "iron_ore": 1.0 }, "outputs": { "iron_plate": 1.0 }, "duration": 1.0 }
	var constructor_rec = { "inputs": { "iron_plate": 1.0 }, "outputs": { "iron_gear": 1.0 }, "duration": 1.0 }
	var seller_rec = { "inputs": { "iron_gear": 1.0 }, "outputs": { "credits": 5.0 }, "duration": 1.0 }
	
	# Create 500 chains of Miner -> Smelter -> Constructor -> Seller (total 2000 buildings)
	var build_start_time = Time.get_ticks_msec()
	
	net.batch_mode = true
	for i in range(500):
		var miner = net.add_building("miner", Vector2i(i, 0), miner_rec)
		var smelter = net.add_building("smelter", Vector2i(i, 1), smelter_rec)
		var constructor = net.add_building("constructor", Vector2i(i, 2), constructor_rec)
		var seller = net.add_building("seller", Vector2i(i, 3), seller_rec)
		
		net.add_connection(miner.id, smelter.id)
		net.add_connection(smelter.id, constructor.id)
		net.add_connection(constructor.id, seller.id)
	net.batch_mode = false
	net.rebuild_caches()
		
	var build_time = Time.get_ticks_msec() - build_start_time
	print("Instantiated 2,000 buildings and 1,500 connections in ", build_time, " ms.")
	
	# Perform benchmark ticks
	# Since 2.5 million ticks in interpreted GDScript would take too long, we run a smaller representative number of ticks (e.g. 1,000 ticks)
	# and project the total time, and see how many ticks we can do per second.
	var test_ticks = 1000
	print("Running ", test_ticks, " performance ticks...")
	
	var sim_start_time = Time.get_ticks_msec()
	for t in range(test_ticks):
		net.tick(1.0, economy)
	var sim_time = Time.get_ticks_msec() - sim_start_time
	
	var ticks_per_sec = (float(test_ticks) / sim_time) * 1000.0
	print("Simulated ", test_ticks, " ticks in ", sim_time, " ms (", snappedf(ticks_per_sec, 0.1), " ticks/sec).")
	
	# Project to 30 days (2,592,000 ticks)
	var projected_30_days_sec = 2592000.0 / ticks_per_sec
	print("Projected time for 30 days (2,592,000 ticks): ", snappedf(projected_30_days_sec, 0.1), " seconds.")
	
	print("Credits accumulated: ", economy.get_resource("credits"))
	
	# Test hybrid offline catch-up simulation
	print("\n--- Testing Hybrid Offline Catch-up Simulation ---")
	var catchup_net = FactoryNetwork.new()
	var catchup_economy = EconomyManager.new()
	catchup_economy.resources["credits"] = 100.0 # Starter
	
	# Build 500 chains
	catchup_net.batch_mode = true
	for i in range(500):
		var miner = catchup_net.add_building("miner", Vector2i(i, 0), miner_rec)
		var smelter = catchup_net.add_building("smelter", Vector2i(i, 1), smelter_rec)
		var constructor = catchup_net.add_building("constructor", Vector2i(i, 2), constructor_rec)
		var seller = catchup_net.add_building("seller", Vector2i(i, 3), seller_rec)
		
		catchup_net.add_connection(miner.id, smelter.id)
		catchup_net.add_connection(smelter.id, constructor.id)
		catchup_net.add_connection(constructor.id, seller.id)
	catchup_net.batch_mode = false
	catchup_net.rebuild_caches()
	
	var ticker = SimulationTicker.new(catchup_net, catchup_economy)
	var offline_seconds = 2592000 # 30 days
	var simulated_time_start = Time.get_ticks_msec()
	
	# Simulate offline catchup (current time - offline_seconds)
	var last_save_time = int(Time.get_unix_time_from_system()) - offline_seconds
	var catchup_result = ticker.catch_up_offline(last_save_time)
	
	var simulated_time = Time.get_ticks_msec() - simulated_time_start
	print("Offline catch-up simulated: ", catchup_result["simulated_ticks"], " seconds in ", simulated_time, " ms.")
	print("Credits earned offline: ", catchup_result["credits_earned"])
	print("New total credits: ", catchup_economy.get_resource("credits"))
	
	if simulated_time < 2000:
		print("[PASS] 30 days offline simulation completed in under 2 seconds (Actual: ", simulated_time, " ms).")
	else:
		print("[FAIL] 30 days offline simulation took too long: ", simulated_time, " ms.")
		
	# Verify that math is correct
	# In steady state, 500 chains produce 2500 credits per tick.
	# The hybrid simulation runs 400 ticks physically, then projects 2591600 ticks.
	# Each physical tick in steady state earns 2500. So projection is 2591600 * 2500 = 6,479,000,000.
	# Total earned should be very close to 6.48 billion credits!
	if catchup_result["credits_earned"] > 6000000000.0:
		print("[PASS] Offline credits calculation is mathematically correct.")
	else:
		print("[FAIL] Offline credits calculation seems low: ", catchup_result["credits_earned"])
		
	print("==================================================")
