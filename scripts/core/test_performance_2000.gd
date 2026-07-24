extends SceneTree

func _init() -> void:
	print("==================================================")
	print("Starting Performance Benchmark: 2000 Buildings")
	print("==================================================")
	
	run_benchmark()
	quit()

func run_benchmark() -> void:
	var net = FactoryNetwork.new()
	var res_mgr = ResourceManager.new()
	var mod_mgr = ModifierManager.new()
	var ms_mgr = MilestonesManager.new()
	var art_mgr = ArtifactsManager.new(mod_mgr)
	
	print("Building 2000 factory network nodes...")
	net.batch_mode = true
	
	var miner_rec = { "inputs": {}, "outputs": { "iron_ore": 1.0 }, "duration": 1.0 }
	var smelter_rec = { "inputs": { "iron_ore": 1.0 }, "outputs": { "iron_plate": 1.0 }, "duration": 1.0 }
	var seller_rec = { "inputs": { "iron_plate": 1.0 }, "outputs": { "credits": 5.0 }, "duration": 1.0 }
	
	# Spawn 666 Miners, 666 Smelters, 666 Sellers = ~2000 buildings
	var last_miners = []
	var last_smelters = []
	
	var col_count = 50
	for i in range(666):
		var grid_x = (i % col_count) * 4
		var grid_y = (i / col_count) * 12
		
		var m = net.add_building("miner", Vector2i(grid_x, grid_y), miner_rec)
		var s = net.add_building("smelter", Vector2i(grid_x, grid_y + 4), smelter_rec)
		var sel = net.add_building("seller", Vector2i(grid_x, grid_y + 8), seller_rec)
		
		if m and s and sel:
			net.add_connection(m.id, s.id)
			net.add_connection(s.id, sel.id)
			
	net.batch_mode = false
	net.rebuild_caches()
	
	print("Network initialized: %d buildings, %d connections." % [net.buildings.size(), net.connections.size()])
	
	print("Running 300 simulation ticks (10 seconds of real-time 30FPS factory simulation)...")
	var start_time = Time.get_ticks_usec()
	
	for t in range(300):
		net.tick(1.0 / 30.0, res_mgr, mod_mgr, ms_mgr, art_mgr)
		
	var end_time = Time.get_ticks_usec()
	var total_ms = (end_time - start_time) / 1000.0
	var avg_tick_ms = total_ms / 300.0
	var max_simulated_fps = 1000.0 / avg_tick_ms if avg_tick_ms > 0 else 9999.0
	
	print("\n--- PERFORMANCE RESULTS ---")
	print("Total time for 300 ticks: %.2f ms" % total_ms)
	print("Average simulation tick time: %.3f ms" % avg_tick_ms)
	print("Theoretical max simulation TPS: %.0f Ticks/Sec" % max_simulated_fps)
	
	if avg_tick_ms < 5.0: # Less than 5ms tick time out of 33ms budget for 30FPS
		print("[PASS] Simulation backend is extremely fast and capable of 2000+ buildings at 60 FPS!")
	else:
		print("[WARN] Simulation tick time is %.3f ms" % avg_tick_ms)
