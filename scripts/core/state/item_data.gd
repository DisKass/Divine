class_name ItemData
extends RefCounted

const AffixDb = preload("res://scripts/core/systems/affix_database.gd")

## Zone of Responsibility: Represents a unique crafted artifact instance with its rolled stats.


var uid: String = ""
var base_id: String = ""
var aoe_size: int = 1

# Stat Dictionaries
# implicit_stats: modifier_name -> float value
# prefixes / suffixes: mod_name -> Dictionary {"id", "tier", "value", "tag", "text"} or float value (for legacy compatibility)
var implicit_stats: Dictionary = {}
var prefixes: Dictionary = {}
var suffixes: Dictionary = {}

func _init(p_uid: String = "", p_base: String = "") -> void:
	uid = p_uid
	base_id = p_base

func is_white() -> bool:
	return prefixes.is_empty() and suffixes.is_empty()

func get_total_affixes_count() -> int:
	return prefixes.size() + suffixes.size()

func to_dict() -> Dictionary:
	return {
		"uid": uid,
		"base_id": base_id,
		"aoe_size": aoe_size,
		"implicit_stats": implicit_stats.duplicate(true),
		"prefixes": prefixes.duplicate(true),
		"suffixes": suffixes.duplicate(true)
	}

static func from_dict(data: Dictionary) -> ItemData:
	var item = ItemData.new(data.get("uid", ""), data.get("base_id", ""))
	item.aoe_size = int(data.get("aoe_size", 1))
	item.implicit_stats = data.get("implicit_stats", {}).duplicate(true)
	item.prefixes = data.get("prefixes", {}).duplicate(true)
	item.suffixes = data.get("suffixes", {}).duplicate(true)
	return item

## Helper to extract numeric value from an entry that can be either float or Dictionary
static func extract_value_from_entry(entry: Variant) -> float:
	if typeof(entry) == TYPE_DICTIONARY:
		return float((entry as Dictionary).get("value", 0.0))
	elif typeof(entry) == TYPE_FLOAT or typeof(entry) == TYPE_INT:
		return float(entry)
	return 0.0

## Helper to extract tag string from an entry
static func extract_tag_from_entry(entry: Variant) -> String:
	if typeof(entry) == TYPE_DICTIONARY:
		return str((entry as Dictionary).get("tag", "all"))
	return "all"

const PERCENT_MODIFIERS: Dictionary = {
	"factory_speed": true,
	"acceleration_cont": true,
	"acceleration_inter": true,
	"sell_multiplier": true
}

## Calculates total bonus of a specific modifier name for a target building type.
## Evaluates building tags ([All], [Smelter], etc.) and excludes non-production buildings.
func get_modifier_value_for_building(mod_name: String, building_type: String = "") -> float:
	var total = 0.0
	
	# Implicits apply globally unless building_type is excluded
	if implicit_stats.has(mod_name):
		total += float(implicit_stats[mod_name])
		
	# Helper for evaluating prefixes and suffixes
	var pools = [prefixes, suffixes]
	for pool in pools:
		if pool.has(mod_name):
			var entry = pool[mod_name]
			var val = extract_value_from_entry(entry)
			var tag = extract_tag_from_entry(entry)
			
			if is_tag_applicable_to_building(tag, building_type):
				if PERCENT_MODIFIERS.has(mod_name) and typeof(entry) == TYPE_DICTIONARY:
					total += val / 100.0
				else:
					total += val
				
	return total


## Returns whether a tag is applicable to a specific building type.
static func is_tag_applicable_to_building(tag: String, building_type: String) -> bool:
	if building_type != "" and AffixDb.EXCLUDED_BUILDING_TYPES.has(building_type):
		return false

		
	if tag == "all":
		return true
	if building_type == "" or building_type == "all":
		return true
	return tag == building_type

## Legacy getter: Returns unconditional sum of modifier
func get_modifier_total(mod_name: String) -> float:
	return get_modifier_value_for_building(mod_name, "")

## Gets additional AoE radius granted by aoe_bonus suffix
func get_aoe_bonus() -> int:
	if suffixes.has("aoe_bonus"):
		return int(extract_value_from_entry(suffixes["aoe_bonus"]))
	return 0

## Gets final effective AoE radius including base size and aoe_bonus suffix
func get_effective_aoe_size() -> int:
	return aoe_size + get_aoe_bonus()


## Returns all formatted text lines for display in tooltips and inspector panels.
func get_formatted_affix_lines() -> Array[String]:
	var lines: Array[String] = []
	
	for mod_name in prefixes:
		var entry = prefixes[mod_name]
		if typeof(entry) == TYPE_DICTIONARY and entry.has("text"):
			lines.append(str(entry["text"]))
		else:
			lines.append(mod_name + ": +" + str(extract_value_from_entry(entry)))
			
	for mod_name in suffixes:
		var entry = suffixes[mod_name]
		if typeof(entry) == TYPE_DICTIONARY and entry.has("text"):
			lines.append(str(entry["text"]))
		else:
			lines.append(mod_name + ": +" + str(extract_value_from_entry(entry)))
			
	return lines

## Returns all unique modifier names present on this item.
func get_all_modifier_names() -> Array[String]:
	var names_dict = {}
	for k in implicit_stats: names_dict[k] = true
	for k in prefixes: names_dict[k] = true
	for k in suffixes: names_dict[k] = true
	
	var arr: Array[String] = []
	for k in names_dict:
		arr.append(k)
	return arr
