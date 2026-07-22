extends SceneTree

func _init() -> void:
	print("==================================================")
	print("Starting Test: Splitters & Multi-Port Connections")
	print("==================================================")
	
	verify_splitter_flow()
	verify_serialization()
	quit()

func verify_splitter_flow() -> void:
	print("\n--- Verifying Splitter Flow ---")
	var net = FactoryNetwork.new()
	var res_mgr = ResourceManager.new()
	var mod_mgr = ModifierManager.new()
	var ms_mgr = MilestonesManager.new()
	var art_mgr = ArtifactsManager.new(mod_mgr)
	
	var miner_rec = { "inputs": {}, "outputs": { "iron_ore": 1.0 }, "duration": 1.0 }
	var smelter_rec = { "inputs": { "iron_ore": 1.0 }, "outputs": { "iron_plate": 1.0 }, "duration": 1.0 }
	
	var miner = net.add_building("miner", Vector2i(0, 0), miner_rec)
	var splitter = net.add_building("splitter_2", Vector2i(0, 4), {})
	var smelter1 = net.add_building("smelter", Vector2i(-5, 8), smelter_rec)
	var smelter2 = net.add_building("smelter", Vector2i(5, 8), smelter_rec)
	
	# Connect miner -> splitter
	net.add_connection(miner.id, splitter.id, 0, 0)
	# Connect splitter port 0 -> smelter1, port 1 -> smelter2
	var c1 = net.add_connection(splitter.id, smelter1.id, 0, 0)
	var c2 = net.add_connection(splitter.id, smelter2.id, 1, 0)
	
	if c1 and c2 and net.connections.size() == 3:
		print("[PASS] Added 2 connections from separate output ports of splitter_2 successfully.")
	else:
		print("[FAIL] Failed to add sub-port connections to splitter_2.")
		
	# Tick simulation
	for i in range(10):
		net.tick(1.0, res_mgr, mod_mgr, ms_mgr, art_mgr)
		
	var s1_inputs = smelter1.inputs.get("iron_ore", 0.0) + smelter1.outputs.get("iron_plate", 0.0)
	var s2_inputs = smelter2.inputs.get("iron_ore", 0.0) + smelter2.outputs.get("iron_plate", 0.0)
	
	if s1_inputs > 0 and s2_inputs > 0:
		print("[PASS] Splitter successfully distributed items to both downstream targets: S1=%d, S2=%d" % [s1_inputs, s2_inputs])
	else:
		print("[FAIL] Splitter distribution failed. S1=%d, S2=%d" % [s1_inputs, s2_inputs])

func verify_serialization() -> void:
	print("\n--- Verifying Multi-Port Connection Serialization ---")
	var net = FactoryNetwork.new()
	var b1 = net.add_building("miner", Vector2i(0, 0), {})
	var sp = net.add_building("splitter_2", Vector2i(0, 3), {})
	var b2 = net.add_building("smelter", Vector2i(-5, 6), {})
	var b3 = net.add_building("smelter", Vector2i(5, 6), {})
	
	net.add_connection(b1.id, sp.id, 0, 0)
	net.add_connection(sp.id, b2.id, 0, 0)
	net.add_connection(sp.id, b3.id, 1, 0)
	
	var serialized = net.to_dict()
	var restored = FactoryNetwork.from_dict(serialized)
	
	if restored.connections.size() == 3 and restored.connections[2]["from_port"] == 1:
		print("[PASS] Serialization & deserialization of sub-port connections verified!")
	else:
		print("[FAIL] Serialization of sub-port connections failed.")
