class_name BuildingCostData
extends Resource

## Zone of Responsibility: Data container for building tiers, limits, and cost scaling.

@export var tier: int = 1
@export var multiplier: float = 1.15
@export var max_count: int = -1 # -1 means no limit

# Costs for the very first building (count == 0)
@export var base_costs: Dictionary = {}

# Costs for the first non-free building (count >= 1)
# The multiplier applies to this base.
@export var first_paid_costs: Dictionary = {}
