class_name ChainTargetResolver
extends Node


func resolve_chain(
	origin: Vector3,
	aim_position: Vector3,
	candidates: Array[HurtboxComponent],
	source_faction: StringName,
	acquire_range: float,
	jump_range: float,
	max_targets: int
) -> Array[HurtboxComponent]:
	var result: Array[HurtboxComponent] = []
	if acquire_range <= 0.0 or jump_range <= 0.0 or max_targets <= 0:
		return result

	var available: Array[HurtboxComponent] = []
	for hurtbox: HurtboxComponent in candidates:
		if _is_valid_target(hurtbox, source_faction) \
			and _flat_distance_squared(origin, hurtbox.global_position) <= acquire_range * acquire_range:
			available.append(hurtbox)
	if available.is_empty():
		return result

	var current: HurtboxComponent = _nearest_to(aim_position, available)
	while current != null and result.size() < max_targets:
		result.append(current)
		available.erase(current)
		current = _nearest_within(current.global_position, available, jump_range)
	return result


func _is_valid_target(hurtbox: HurtboxComponent, source_faction: StringName) -> bool:
	return is_instance_valid(hurtbox) \
		and not hurtbox.belongs_to(source_faction) \
		and is_instance_valid(hurtbox.health_component) \
		and hurtbox.health_component.is_alive()


func _nearest_to(position: Vector3, candidates: Array[HurtboxComponent]) -> HurtboxComponent:
	var best: HurtboxComponent
	var best_distance: float = INF
	var best_id: int = 0
	for candidate: HurtboxComponent in candidates:
		var distance: float = _flat_distance_squared(position, candidate.global_position)
		var candidate_id: int = candidate.get_instance_id()
		if distance < best_distance or (is_equal_approx(distance, best_distance) and candidate_id < best_id):
			best = candidate
			best_distance = distance
			best_id = candidate_id
	return best


func _nearest_within(
	position: Vector3,
	candidates: Array[HurtboxComponent],
	maximum_distance: float
) -> HurtboxComponent:
	var nearby: Array[HurtboxComponent] = []
	var maximum_squared: float = maximum_distance * maximum_distance
	for candidate: HurtboxComponent in candidates:
		if _flat_distance_squared(position, candidate.global_position) <= maximum_squared:
			nearby.append(candidate)
	return _nearest_to(position, nearby) if not nearby.is_empty() else null


func _flat_distance_squared(from: Vector3, to: Vector3) -> float:
	var difference: Vector3 = to - from
	difference.y = 0.0
	return difference.length_squared()
