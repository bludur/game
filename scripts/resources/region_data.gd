class_name RegionData
extends Resource

@export var region_id: StringName = &""
@export var display_name: String = ""
@export_range(1, 10, 1) var region_tier: int = 1
@export var authored_size: Vector2 = Vector2(192.0, 192.0)
@export var spawn_position: Vector3 = Vector3.ZERO
@export var boss_id: StringName = &""


func is_valid_definition() -> bool:
	return not region_id.is_empty() and not display_name.is_empty() \
		and authored_size.x > 0.0 and authored_size.y > 0.0
