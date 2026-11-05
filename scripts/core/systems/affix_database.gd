class_name AffixDatabase
extends RefCounted

## Decoupled database for PoE-style item affixes, tiers, weights, and building tags.

const TAG_WEIGHTS: Dictionary = {
	"all": 50,
	"miner": 500,
	"smelter": 500,
	"converter": 500,
	"assembler": 500,
	"extractor": 500,
	"infuser": 500,
	"seller": 500
}

const TAG_LABELS: Dictionary = {
	"all": "[All]",
	"miner": "[Miner]",
	"smelter": "[Smelter]",
	"converter": "[Converter]",
	"assembler": "[Assembler]",
	"extractor": "[Extractor]",
	"infuser": "[Infuser]",
	"seller": "[Seller]",
	"altar": "[Altar]"
}

# Non-production building types that are completely ignored by [All] and do not have tags
const EXCLUDED_BUILDING_TYPES: Array[String] = [
	"shell_forge",
	"shell_infuser",
	"purifier",
	"vault_gateway",
	"artifact_altar",
	"the_void",
	"splitter_2",
	"splitter_3",
	"portal"
]

const PREFIX_DEFINITIONS: Dictionary = {
	"factory_speed": {
		"name": "factory_speed",
		"is_prefix": true,
		"has_building_tag": true,
		"tiers": [
			{"tier": 5, "min_val": 1.0, "max_val": 7.0, "weight": 1500},
			{"tier": 4, "min_val": 8.0, "max_val": 17.0, "weight": 1500},
			{"tier": 3, "min_val": 18.0, "max_val": 34.0, "weight": 1000},
			{"tier": 2, "min_val": 35.0, "max_val": 62.0, "weight": 700},
			{"tier": 1, "min_val": 63.0, "max_val": 97.0, "weight": 500}
		],
		"format_template": "+{val}% к скорости работы зданий {tag_label}"
	},
	"production_flat": {
		"name": "production_flat",
		"is_prefix": true,
		"has_building_tag": true,
		"tiers": [
			{"tier": 3, "min_val": 1.0, "max_val": 1.0, "weight": 1500},
			{"tier": 2, "min_val": 2.0, "max_val": 2.0, "weight": 1000},
			{"tier": 1, "min_val": 3.0, "max_val": 4.0, "weight": 500}
		],
		"format_template": "+{val} к количеству производимых ресурсов {tag_label}"
	},
	"acceleration_cont": {
		"name": "acceleration_cont",
		"is_prefix": true,
		"has_building_tag": true,
		"tiers": [
			{"tier": 4, "min_val": 5.0, "max_val": 12.0, "weight": 1000},
			{"tier": 3, "min_val": 13.0, "max_val": 25.0, "weight": 1000},
			{"tier": 2, "min_val": 26.0, "max_val": 45.0, "weight": 1000},
			{"tier": 1, "min_val": 46.0, "max_val": 75.0, "weight": 1000}
		],
		"format_template": "+{val}% к ускорению при непрерывной работе {tag_label}"
	},
	"acceleration_inter": {
		"name": "acceleration_inter",
		"is_prefix": true,
		"has_building_tag": true,
		"tiers": [
			{"tier": 4, "min_val": 5.0, "max_val": 15.0, "weight": 1000},
			{"tier": 3, "min_val": 16.0, "max_val": 30.0, "weight": 1000},
			{"tier": 2, "min_val": 31.0, "max_val": 50.0, "weight": 1000},
			{"tier": 1, "min_val": 51.0, "max_val": 80.0, "weight": 1000}
		],
		"format_template": "+{val}% к ускорению после простоя {tag_label}"
	},
	"crit_craft_chance": {
		"name": "crit_craft_chance",
		"is_prefix": true,
		"has_building_tag": true,
		"tiers": [
			{"tier": 4, "min_val": 3.0, "max_val": 7.0, "weight": 1000},
			{"tier": 3, "min_val": 8.0, "max_val": 15.0, "weight": 1000},
			{"tier": 2, "min_val": 16.0, "max_val": 25.0, "weight": 1000},
			{"tier": 1, "min_val": 26.0, "max_val": 40.0, "weight": 1000}
		],
		"format_template": "+{val}% шанс на Критический Крафт {tag_label}"
	}
}

const SUFFIX_DEFINITIONS: Dictionary = {
	"double_craft_chance": {
		"name": "double_craft_chance",
		"is_prefix": false,
		"has_building_tag": true,
		"tiers": [
			{"tier": 4, "min_val": 5.0, "max_val": 12.0, "weight": 1000},
			{"tier": 3, "min_val": 13.0, "max_val": 25.0, "weight": 1000},
			{"tier": 2, "min_val": 26.0, "max_val": 45.0, "weight": 1000},
			{"tier": 1, "min_val": 46.0, "max_val": 70.0, "weight": 1000}
		],
		"format_template": "+{val}% шанс произвести х2 ресурсов за 1 цикл {tag_label}"
	},
	"extra_flat_chance": {
		"name": "extra_flat_chance",
		"is_prefix": false,
		"has_building_tag": true,
		"tiers": [
			{"tier": 4, "min_val": 10.0, "max_val": 25.0, "weight": 1000},
			{"tier": 3, "min_val": 26.0, "max_val": 50.0, "weight": 1000},
			{"tier": 2, "min_val": 51.0, "max_val": 90.0, "weight": 1000},
			{"tier": 1, "min_val": 91.0, "max_val": 150.0, "weight": 1000}
		],
		"format_template": "+{val}% шанс произвести +X (флат) ресурсов за 1 цикл {tag_label}"
	},
	"save_input_chance": {
		"name": "save_input_chance",
		"is_prefix": false,
		"has_building_tag": true,
		"tiers": [
			{"tier": 4, "min_val": 3.0, "max_val": 8.0, "weight": 1000},
			{"tier": 3, "min_val": 9.0, "max_val": 16.0, "weight": 1000},
			{"tier": 2, "min_val": 17.0, "max_val": 25.0, "weight": 1000},
			{"tier": 1, "min_val": 26.0, "max_val": 40.0, "weight": 1000}
		],
		"format_template": "+{val}% шанс НЕ потратить входной ресурс при крафте {tag_label}"
	},
	"sell_multiplier": {
		"name": "sell_multiplier",
		"is_prefix": false,
		"has_building_tag": false,
		"fixed_tag": "seller",
		"tiers": [
			{"tier": 4, "min_val": 10.0, "max_val": 25.0, "weight": 1000},
			{"tier": 3, "min_val": 26.0, "max_val": 50.0, "weight": 1000},
			{"tier": 2, "min_val": 51.0, "max_val": 90.0, "weight": 1000},
			{"tier": 1, "min_val": 91.0, "max_val": 150.0, "weight": 1000}
		],
		"format_template": "+{val}% к стоимости продажи предметов"
	},
	"aoe_bonus": {
		"name": "aoe_bonus",
		"is_prefix": false,
		"has_building_tag": false,
		"fixed_tag": "altar",
		"tiers": [
			{"tier": 3, "min_val": 1.0, "max_val": 1.0, "weight": 1500},
			{"tier": 2, "min_val": 2.0, "max_val": 2.0, "weight": 1000},
			{"tier": 1, "min_val": 3.0, "max_val": 3.0, "weight": 500}
		],
		"format_template": "+{val} ячейка к радиусу зоны действия Алтаря"
	}
}

static func get_affix_definition(affix_id: String) -> Dictionary:
	if PREFIX_DEFINITIONS.has(affix_id):
		return PREFIX_DEFINITIONS[affix_id]
	if SUFFIX_DEFINITIONS.has(affix_id):
		return SUFFIX_DEFINITIONS[affix_id]
	return {}

## Rolls a random tag according to TAG_WEIGHTS.
static func roll_random_tag() -> String:
	var total_weight = 0
	for t in TAG_WEIGHTS:
		total_weight += int(TAG_WEIGHTS[t])
		
	var rng_val = randi() % total_weight
	var current_sum = 0
	for t in TAG_WEIGHTS:
		current_sum += int(TAG_WEIGHTS[t])
		if rng_val < current_sum:
			return t
	return "all"

## Rolls a single affix (tier, value, tag, text).
static func roll_affix(affix_id: String) -> Dictionary:
	var def = get_affix_definition(affix_id)
	if def.is_empty():
		return {}
		
	var tiers: Array = def.get("tiers", [])
	var total_tier_weight = 0
	for t in tiers:
		total_tier_weight += int(t.get("weight", 1000))
		
	var chosen_tier_dict = tiers[0]
	if total_tier_weight > 0:
		var rng_val = randi() % total_tier_weight
		var current_sum = 0
		for t in tiers:
			current_sum += int(t.get("weight", 1000))
			if rng_val < current_sum:
				chosen_tier_dict = t
				break
				
	var min_v = float(chosen_tier_dict.get("min_val", 1.0))
	var max_v = float(chosen_tier_dict.get("max_val", 1.0))
	var rolled_val = 0.0
	if min_v == max_v:
		rolled_val = min_v
	else:
		# Roll integer or float value nicely
		rolled_val = float(randi_range(int(min_v), int(max_v)))
		
	var tag_id = ""
	if def.get("has_building_tag", true):
		tag_id = roll_random_tag()
	else:
		tag_id = def.get("fixed_tag", "all")
		
	var text_str = format_affix_text(def, rolled_val, tag_id, int(chosen_tier_dict.get("tier", 1)))
	
	return {
		"id": affix_id,
		"tier": int(chosen_tier_dict.get("tier", 1)),
		"value": rolled_val,
		"tag": tag_id,
		"text": text_str
	}

static func format_affix_text(def: Dictionary, val: float, tag_id: String, tier: int) -> String:
	var template = str(def.get("format_template", "{val} {tag_label}"))
	var tag_label = TAG_LABELS.get(tag_id, "[All]")
	var val_str = str(int(val)) if val == floor(val) else str(snappedf(val, 0.1))
	var formatted = template.replace("{val}", val_str).replace("{tag_label}", tag_label)
	return formatted + " (T" + str(tier) + ")"
