class_name EncounterEntryData
extends Resource

enum TimeRule {
	ANY,
	DAY,
	NIGHT,
}

@export var encounter_id: StringName = &""
@export var time_rule: TimeRule = TimeRule.ANY
@export_range(0.0, 100.0, 1.0) var minimum_corruption: float = 0.0
@export_range(0.0, 100.0, 1.0) var maximum_corruption: float = 100.0
@export_range(1, 5, 1) var minimum_tier: int = 1
@export_range(1, 5, 1) var maximum_tier: int = 5
@export_range(-1, 11, 1) var poi_kind: int = -1
@export var role_ids: Array[StringName] = []
@export_range(1, 8, 1) var minimum_group_size: int = 1
@export_range(1, 8, 1) var maximum_group_size: int = 3


func matches(is_night: bool, corruption: float, tier: int, candidate_poi_kind: int) -> bool:
	if time_rule == TimeRule.DAY and is_night:
		return false
	if time_rule == TimeRule.NIGHT and not is_night:
		return false
	return corruption >= minimum_corruption and corruption <= maximum_corruption \
		and tier >= minimum_tier and tier <= maximum_tier \
		and (poi_kind < 0 or poi_kind == candidate_poi_kind)


func is_valid_definition() -> bool:
	return not encounter_id.is_empty() and not role_ids.is_empty() \
		and maximum_corruption >= minimum_corruption \
		and maximum_tier >= minimum_tier \
		and maximum_group_size >= minimum_group_size
