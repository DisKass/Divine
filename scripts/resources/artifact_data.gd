class_name ArtifactData
extends Resource

## Zone of Responsibility: Data container for artifact definitions and their modifiers.

@export var id: String = ""
@export var name: String = ""
@export_multiline var description: String = ""

# Dictionary of string (modifier_id) -> float (bonus_value)
# e.g., {"factory_speed": 0.25, "logistics_transfer": 0.25}
@export var modifiers: Dictionary = {}
