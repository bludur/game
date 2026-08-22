class_name EnemyLairData
extends Resource

@export var lair_id: StringName = &""
@export var poi_id: StringName = &""
@export_range(0, 11, 1) var poi_kind: int = 0
@export var encounter_id: StringName = &""
@export var world_position: Vector3 = Vector3.ZERO
@export var patrol_points: Array[Vector3] = []
@export_range(1, 8, 1) var population_budget: int = 2
@export_range(5.0, 900.0, 5.0) var respawn_seconds: float = 180.0


func is_valid_definition() -> bool:
	return not lair_id.is_empty() and not poi_id.is_empty() \
		and not encounter_id.is_empty() and population_budget > 0 \
		and patrol_points.size() >= 2 and respawn_seconds > 0.0
