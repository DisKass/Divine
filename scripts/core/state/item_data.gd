class_name ItemData
extends RefCounted

## Zone of Responsibility: Represents a unique crafted artifact instance with its rolled stats.

var uid: String = ""
var base_id: String = ""
var aoe_size: int = 1

# Stat Dictionaries (modifier_name -> value)
var implicit_stats: Dictionary = {}
var prefixes: Dictionary = {}
var suffixes: Dictionary = {}

func _init(p_uid: String = "", p_base: String = "") -> void:
	uid = p_uid
	base_id = p_base

func to_dict() -> Dictionary:
	return {
		"uid": uid,
		"base_id": base_id,
		"aoe_size": aoe_size,
		"implicit_stats": implicit_stats.duplicate(),
		"prefixes": prefixes.duplicate(),
		"suffixes": suffixes.duplicate()
	}

static func from_dict(data: Dictionary) -> ItemData:
	var item = ItemData.new(data.get("uid", ""), data.get("base_id", ""))
	item.aoe_size = int(data.get("aoe_size", 1))
	item.implicit_stats = data.get("implicit_stats", {}).duplicate()
	item.prefixes = data.get("prefixes", {}).duplicate()
	item.suffixes = data.get("suffixes", {}).duplicate()
	return item

## Returns the combined total of a specific modifier from implicits, prefixes, and suffixes.
func get_modifier_total(mod_name: String) -> float:
	var total = 0.0
	total += float(implicit_stats.get(mod_name, 0.0))
	total += float(prefixes.get(mod_name, 0.0))
	total += float(suffixes.get(mod_name, 0.0))
	return total

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
