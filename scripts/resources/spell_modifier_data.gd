class_name SpellModifierData
extends Resource

enum School {
	ARCANE,
	FROST,
	STORM,
	FORBIDDEN,
}

@export var modifier_id: StringName = &""
@export var display_name: String = ""
@export var school: School = School.ARCANE
@export_range(0.1, 4.0, 0.05) var damage_multiplier: float = 1.0
@export_range(0.1, 4.0, 0.05) var mana_multiplier: float = 1.0
@export_range(0.1, 4.0, 0.05) var radius_multiplier: float = 1.0
@export_range(0.0, 40.0, 0.5) var corruption_cost: float = 0.0
