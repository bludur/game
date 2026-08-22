class_name EnemyMutationData
extends Resource

@export var mutation_id: StringName = &""
@export var display_name: String = ""
@export var signature_color: Color = Color(0.8, 0.25, 0.9, 1.0)
@export_range(0.0, 100.0, 1.0) var minimum_corruption: float = 25.0
@export_range(1.0, 3.0, 0.05) var health_multiplier: float = 1.25
@export_range(1.0, 3.0, 0.05) var damage_multiplier: float = 1.15
@export_range(0.5, 2.0, 0.05) var speed_multiplier: float = 1.0


func is_valid_definition() -> bool:
	return not mutation_id.is_empty() and not display_name.is_empty() \
		and health_multiplier >= 1.0 and damage_multiplier >= 1.0 \
		and speed_multiplier > 0.0
