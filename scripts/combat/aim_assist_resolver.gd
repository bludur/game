class_name AimAssistResolver
extends RefCounted


func choose_target(
	origin: Vector3,
	forward: Vector3,
	candidates: Array[HurtboxComponent],
	maximum_range: float,
	cone_degrees: float
) -> HurtboxComponent:
	if forward.length_squared() <= 0.001 or maximum_range <= 0.0 or cone_degrees <= 0.0:
		return null
	var normalized_forward: Vector3 = forward.normalized()
	var minimum_dot: float = cos(deg_to_rad(cone_degrees))
	var best_target: HurtboxComponent
	var best_score: float = -INF
	for candidate: HurtboxComponent in candidates:
		if not is_instance_valid(candidate) or candidate.faction != &"enemy":
			continue
		var to_candidate: Vector3 = candidate.global_position - origin
		var distance: float = to_candidate.length()
		if distance <= 0.001 or distance > maximum_range:
			continue
		var alignment: float = normalized_forward.dot(to_candidate / distance)
		if alignment < minimum_dot:
			continue
		var score: float = alignment - distance * 0.0005
		if score > best_score:
			best_target = candidate
			best_score = score
	return best_target
