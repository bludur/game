class_name WaveData
extends Resource

@export_group("Identity")
@export var wave_id: StringName
@export var display_name: String = "Wave"

@export_group("Enemies")
@export_range(0, 20, 1) var chaser_count: int = 0
@export_range(0, 20, 1) var cultist_count: int = 0
@export_range(0.05, 5.0, 0.05) var spawn_interval: float = 0.35


func get_total_enemy_count() -> int:
	return chaser_count + cultist_count


func is_valid_definition() -> bool:
	return not String(wave_id).is_empty() \
		and not display_name.is_empty() \
		and get_total_enemy_count() > 0 \
		and spawn_interval > 0.0
