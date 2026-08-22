class_name EnemyTelegraphData
extends Resource

@export var telegraph_id: StringName
@export var warning_color: Color = Color(0.72, 0.2, 1.0, 0.42)
@export var danger_color: Color = Color(1.0, 0.08, 0.14, 0.62)
@export_range(0.1, 3.0, 0.05) var warning_seconds: float = 0.55
@export_range(0.05, 2.0, 0.05) var danger_seconds: float = 0.2
@export_range(0.2, 12.0, 0.1) var danger_radius: float = 1.5
@export var sound_cue: StringName = &"enemy_warning"


func is_valid_definition() -> bool:
	return not String(telegraph_id).is_empty() \
		and warning_seconds > 0.0 \
		and danger_seconds > 0.0 \
		and danger_radius > 0.0 \
		and not String(sound_cue).is_empty()
