extends SceneTree

const EconomyManager = preload("res://scripts/core/economy_manager.gd")
const UpgradeData = preload("res://scripts/resources/upgrade_data.gd")
const ArtifactData = preload("res://scripts/resources/artifact_data.gd")
const MilestoneData = preload("res://scripts/resources/milestone_data.gd")
const BuildingCostData = preload("res://scripts/resources/building_cost_data.gd")

func _init() -> void:
	print("Starting Data Generation...")
	
	# Generate Upgrades
	for up_id in EconomyManager.UPGRADE_CONFIGS:
		var cfg = EconomyManager.UPGRADE_CONFIGS[up_id]
		var data = UpgradeData.new()
		data.id = up_id
		data.name = cfg.get("name", "")
		data.description = cfg.get("description", "")
		data.base_cost = cfg.get("base_cost", 50.0)
		data.cost_multiplier = cfg.get("cost_multiplier", 1.5)
		data.max_level = cfg.get("max_level", 10)
		data.bonus_per_level = cfg.get("bonus_per_level", 0.1)
		var path = "res://data/upgrades/" + up_id + ".tres"
		ResourceSaver.save(data, path)
		print("Saved " + path)

	# Generate Artifacts
	for art_id in EconomyManager.ARTIFACT_CONFIGS:
		var cfg = EconomyManager.ARTIFACT_CONFIGS[art_id]
		var data = ArtifactData.new()
		data.id = art_id
		data.name = cfg.get("name", "")
		data.description = cfg.get("description", "")
		data.modifiers = cfg.get("modifiers", {})
		var path = "res://data/artifacts/" + art_id + ".tres"
		ResourceSaver.save(data, path)
		print("Saved " + path)

	# Generate Milestones
	for m_cfg in EconomyManager.MILESTONES:
		var data = MilestoneData.new()
		var tier = m_cfg.get("tier", 1)
		data.tier = tier
		data.name = m_cfg.get("name", "")
		data.requirements = m_cfg.get("requirements", {})
		var path = "res://data/milestones/tier_" + str(tier) + ".tres"
		ResourceSaver.save(data, path)
		print("Saved " + path)
		
	# Generate Buildings Cost
	var eco = EconomyManager.new()
	for b_id in eco.cost_configs:
		var cfg = eco.cost_configs[b_id]
		var data = BuildingCostData.new()
		data.tier = cfg.get("tier", 1)
		data.multiplier = cfg.get("multiplier", 1.15)
		data.max_count = cfg.get("max_count", -1)
		data.base_costs = cfg.get("base_costs", {})
		data.first_paid_costs = cfg.get("first_paid_costs", {})
		var path = "res://data/buildings/" + b_id + ".tres"
		ResourceSaver.save(data, path)
		print("Saved " + path)

	print("Data Generation Complete!")
	quit()
