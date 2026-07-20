extends SceneTree

const HUD = preload("res://scripts/visual/hud.gd")
const ShopPanel = preload("res://scripts/visual/shop_panel.gd")
const ArtifactsPanel = preload("res://scripts/visual/artifacts_panel.gd")
const InspectorPanel = preload("res://scripts/visual/inspector_panel.gd")

func _init() -> void:
	print("Starting UI conversion...")
	
	# 1. HUD
	var hud = HUD.new()
	hud._create_hud()
	_set_owner_recursive(hud, hud)
	var pack_hud = PackedScene.new()
	pack_hud.pack(hud)
	ResourceSaver.save(pack_hud, "res://scenes/hud.tscn")
	print("Saved hud.tscn")
	
	# 2. ShopPanel
	var shop = ShopPanel.new()
	shop._create_shop_ui()
	_set_owner_recursive(shop, shop)
	var pack_shop = PackedScene.new()
	pack_shop.pack(shop)
	ResourceSaver.save(pack_shop, "res://scenes/shop_panel.tscn")
	print("Saved shop_panel.tscn")
	
	# 3. ArtifactsPanel
	var artifacts = ArtifactsPanel.new()
	artifacts._create_panel_ui()
	_set_owner_recursive(artifacts, artifacts)
	var pack_artifacts = PackedScene.new()
	pack_artifacts.pack(artifacts)
	ResourceSaver.save(pack_artifacts, "res://scenes/artifacts_panel.tscn")
	print("Saved artifacts_panel.tscn")
	
	# 4. InspectorPanel
	var inspector = InspectorPanel.new()
	inspector._create_inspector_ui()
	_set_owner_recursive(inspector, inspector)
	var pack_inspector = PackedScene.new()
	pack_inspector.pack(inspector)
	ResourceSaver.save(pack_inspector, "res://scenes/inspector_panel.tscn")
	print("Saved inspector_panel.tscn")
	
	print("UI Conversion Complete!")
	quit()

func _set_owner_recursive(node: Node, root: Node) -> void:
	if node != root:
		node.owner = root
	for child in node.get_children():
		_set_owner_recursive(child, root)
