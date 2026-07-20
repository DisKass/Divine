class_name UpgradeData
extends Resource

## Zone of Responsibility: Data container for global upgrade configuration.

@export var id: String = ""
@export var name: String = ""
@export_multiline var description: String = ""
@export var base_cost: float = 50.0
@export var cost_multiplier: float = 1.5
@export var max_level: int = 10
@export var bonus_per_level: float = 0.15
