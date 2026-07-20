class_name MilestoneData
extends Resource

## Zone of Responsibility: Data container for milestone requirements and tiers.

@export var tier: int = 1
@export var name: String = ""

# Dictionary of string (resource_id) -> float (amount_required)
# e.g., {"iron_plate": 20.0, "iron_gear": 10.0}
@export var requirements: Dictionary = {}
