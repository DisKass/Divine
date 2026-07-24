extends SceneTree

const BuildingVisualScript = preload("res://scripts/visual/building_visual.gd")
const BuildingRendererScript = preload("res://scripts/visual/building_renderer.gd")

func _init() -> void:
	print("==================================================")
	print("Starting Batched Building Rendering Benchmark")
	print("==================================================")
	
	run_benchmark()
	quit()

func run_benchmark() -> void:
	var net = FactoryNetwork.new()
	var visuals_map: Dictionary = {}
	
	net.batch_mode = true
	var miner_rec = { "inputs": {}, "outputs": { "iron_ore": 1.0 }, "duration": 1.0 }
	var smelter_rec = { "inputs": { "iron_ore": 1.0 }, "outputs": { "iron_plate": 1.0 }, "duration": 1.0 }
	var seller_rec = { "inputs": { "iron_plate": 1.0 }, "outputs": { "credits": 5.0 }, "duration": 1.0 }
	
	var col_count = 50
	for i in range(666):
		var grid_x = (i % col_count) * 4
		var grid_y = (i / col_count) * 12
		
		var m = net.add_building("miner", Vector2i(grid_x, grid_y), miner_rec)
		var s = net.add_building("smelter", Vector2i(grid_x, grid_y + 4), smelter_rec)
		var sel = net.add_building("seller", Vector2i(grid_x, grid_y + 8), seller_rec)
		
		for b in [m, s, sel]:
			if b:
				var vis = BuildingVisualScript.new()
				vis.setup(b, 32)
				visuals_map[b.id] = vis
				
	net.batch_mode = false
	
	print("Spawned %d building data nodes and lightweight visual proxies." % visuals_map.size())
	
	var renderer = BuildingRendererScript.new()
	root.add_child(renderer)
	renderer.setup(visuals_map, null, 32)
	
	print("Executing 100 batched render pass iterations...")
	var start_time = Time.get_ticks_usec()
	
	for i in range(100):
		renderer.notification(CanvasItem.NOTIFICATION_DRAW)
		
	var end_time = Time.get_ticks_usec()
	var total_ms = (end_time - start_time) / 1000.0
	var avg_frame_render_ms = total_ms / 100.0
	var max_render_fps = 1000.0 / avg_frame_render_ms if avg_frame_render_ms > 0 else 9999.0
	
	print("\n--- BATCHED RENDER RESULTS ---")
	print("Total time for 100 render passes (1998 buildings): %.2f ms" % total_ms)
	print("Average per-frame render time: %.3f ms" % avg_frame_render_ms)
	print("Theoretical max render FPS: %.0f FPS" % max_render_fps)
	
	if avg_frame_render_ms < 5.0:
		print("[PASS] Batched building renderer is extremely fast (%.3f ms/frame)!" % avg_frame_render_ms)
	else:
		print("[WARN] Batched render time is %.3f ms" % avg_frame_render_ms)
		
	for vis in visuals_map.values():
		if is_instance_valid(vis):
			vis.free()
	renderer.free()
