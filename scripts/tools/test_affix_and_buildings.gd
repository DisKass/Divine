@tool
extends SceneTree

const AffixDatabase = preload("res://scripts/core/systems/affix_database.gd")
const ArtifactSystem = preload("res://scripts/core/systems/artifact_system.gd")
const ItemData = preload("res://scripts/core/state/item_data.gd")

func _init() -> void:
	print("--- STARTING AFFIX & BUILDINGS VERIFICATION TEST ---")
	
	# Test 1: Generation of white base artifact
	var white_dict = ArtifactSystem.generate_artifact("runesteel_amulet")
	var white_item = ItemData.from_dict(white_dict)
	assert(white_item.is_white() == true, "Generated artifact must be white")
	assert(white_item.get_total_affixes_count() == 0, "White artifact must have 0 affixes")
	print("Test 1 Passed: White artifact base generated correctly.")
	
	# Test 2: Infusion logic
	var infused_dict = ArtifactSystem.infuse_artifact(white_dict)
	var infused_item = ItemData.from_dict(infused_dict)
	var count = infused_item.get_total_affixes_count()
	assert(infused_item.is_white() == false, "Infused artifact must not be white")
	assert(count >= 3 and count <= 6, "Infused artifact must have between 3 and 6 affixes, got: %d" % count)
	assert(infused_item.prefixes.size() <= 3, "Prefix count must be <= 3")
	assert(infused_item.suffixes.size() <= 3, "Suffix count must be <= 3")
	
	print("Infused Item Lines:")
	for line in infused_item.get_formatted_affix_lines():
		print("  - " + line)
	print("Test 2 Passed: Infuse logic generated valid affixes.")
	
	# Test 3: Re-infusion pass-through check
	var reinfused_dict = ArtifactSystem.infuse_artifact(infused_dict)
	var reinfused_item = ItemData.from_dict(reinfused_dict)
	assert(reinfused_item.get_total_affixes_count() == count, "Re-infusing already colored artifact must return unchanged")
	print("Test 3 Passed: Re-infusion pass-through confirmed.")
	
	# Test 4: Purification logic
	var purified_dict = ArtifactSystem.purify_artifact(infused_dict)
	var purified_item = ItemData.from_dict(purified_dict)
	assert(purified_item.is_white() == true, "Purified artifact must be white")
	assert(purified_item.get_total_affixes_count() == 0, "Purified artifact must have 0 affixes")
	print("Test 4 Passed: Purification cleared all affixes.")
	
	# Test 5: Building tag applicability checks
	# Craft an item with explicit [Smelter] and [All] tags
	var custom_item = ItemData.new("test_uid", "runesteel_amulet")
	custom_item.prefixes["factory_speed"] = {
		"id": "factory_speed",
		"tier": 1,
		"value": 50.0,
		"tag": "smelter",
		"text": "+50% speed [Smelter]"
	}
	custom_item.prefixes["crit_craft_chance"] = {
		"id": "crit_craft_chance",
		"tier": 1,
		"value": 20.0,
		"tag": "all",
		"text": "+20% crit [All]"
	}
	
	# Check Smelter building
	var smelter_speed = custom_item.get_modifier_value_for_building("factory_speed", "smelter")
	assert(smelter_speed == 0.5, "Smelter must receive [Smelter] speed bonus (0.5), got: %.2f" % smelter_speed)

	
	# Check Miner building (should not receive [Smelter] speed)
	var miner_speed = custom_item.get_modifier_value_for_building("factory_speed", "miner")
	assert(miner_speed == 0.0, "Miner must NOT receive [Smelter] speed bonus")
	
	# Check [All] tag on Smelter vs Shell Infuser (excluded)
	var smelter_crit = custom_item.get_modifier_value_for_building("crit_craft_chance", "smelter")
	assert(smelter_crit == 20.0, "Smelter must receive [All] crit bonus")
	
	var infuser_crit = custom_item.get_modifier_value_for_building("crit_craft_chance", "shell_infuser")
	assert(infuser_crit == 0.0, "Shell Infuser must NOT receive [All] bonus")
	
	print("Test 5 Passed: Building tag applicability rules verified.")
	
	# Test 6: Verify artifact slot capacity limits (max 1 artifact everywhere)
	var BuildingDataRef = load("res://scripts/core/building_data.gd")
	var infuser_b = BuildingDataRef.new(1, "shell_infuser", Vector2i(0, 0), {
		"id": "infuse_artifact",
		"inputs": { "<artifact>": 1.0, "mana_essence": 3.0 },
		"outputs": { "<artifact>": 1.0 },
		"duration": 5.0
	})
	assert(infuser_b.input_slots.size() >= 2, "Shell Infuser must have 2 input slots")
	var art_in_slot = infuser_b.input_slots[0]
	assert(art_in_slot.capacity == 1.0, "Shell Infuser artifact input slot capacity must be 1.0, got: %.1f" % art_in_slot.capacity)
	var art_out_slot = infuser_b.output_slots[0]
	assert(art_out_slot.capacity == 1.0, "Shell Infuser artifact output slot capacity must be 1.0, got: %.1f" % art_out_slot.capacity)
	
	# Test pushing artifact into slot
	var push1 = art_in_slot.push("runesteel_amulet", 1.0, white_dict)
	assert(push1 == 1.0, "First artifact push must succeed")
	assert(art_in_slot.amount == 1.0, "Slot amount must be 1.0")
	assert(art_in_slot.is_full() == true, "Slot must be full after 1 artifact")
	assert(art_in_slot.can_accept("runesteel_amulet") == false, "Slot must reject second artifact")
	var push2 = art_in_slot.push("runesteel_amulet", 1.0, white_dict)
	assert(push2 == 0.0, "Second artifact push must be rejected")
	assert(art_in_slot.amount == 1.0, "Slot amount must remain 1.0")
	
	# Purifier check
	var purifier_b = BuildingDataRef.new(2, "purifier", Vector2i(0, 0), {
		"id": "purify_artifact",
		"inputs": { "<artifact>": 1.0 },
		"outputs": { "<artifact>": 1.0 },
		"duration": 3.0
	})
	assert(purifier_b.input_slots[0].capacity == 1.0, "Purifier input slot capacity must be 1.0")
	assert(purifier_b.output_slots[0].capacity == 1.0, "Purifier output slot capacity must be 1.0")
	
	print("Test 6 Passed: Artifact slot 1.0 capacity enforcement verified.")
	
	print("--- ALL AFFIX TESTS PASSED SUCCESSFULLY! ---")
	quit(0)
