class_name EconomyState
extends RefCounted

## Stores economy data (resources).

# resource_name (String) -> amount (float)
var resources: Dictionary = {}

func to_dict() -> Dictionary:
	return {
		"resources": resources.duplicate()
	}

static func from_dict(data: Dictionary) -> EconomyState:
	var state = EconomyState.new()
	state.load_from_dict(data)
	return state

func load_from_dict(data: Dictionary) -> void:
	resources = data.get("resources", {}).duplicate()
