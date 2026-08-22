extends SceneTree

const WORLD_SCENE: PackedScene = preload("res://scenes/survival/world_session.tscn")


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var session: WorldSession = WORLD_SCENE.instantiate() as WorldSession
	root.add_child(session)
	session.player.get_hurtbox_component().grant_invulnerability(10.0)
	for _warmup_frame: int in 90:
		await physics_frame
	var maximum_process_seconds: float = 0.0
	var maximum_physics_seconds: float = 0.0
	for frame_index: int in 120:
		await physics_frame
		if frame_index == 0:
			continue
		maximum_process_seconds = maxf(maximum_process_seconds, Performance.get_monitor(Performance.TIME_PROCESS))
		maximum_physics_seconds = maxf(maximum_physics_seconds, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
	var node_count: int = _count_nodes(session)
	var object_count: int = roundi(Performance.get_monitor(Performance.OBJECT_COUNT))
	var orphan_count: int = roundi(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var failures: Array[String] = []
	if node_count > 900:
		failures.append("Survival scene exceeded the 900-node budget.")
	if object_count > 3500:
		failures.append("Survival object count exceeded the 3500-object budget.")
	if orphan_count > 12:
		failures.append("Survival scene produced unexpected orphan nodes.")
	if maximum_process_seconds > 0.025:
		failures.append("Survival process frame exceeded 25 ms.")
	if maximum_physics_seconds > 0.025:
		failures.append("Survival physics frame exceeded 25 ms.")
	print("SURVIVAL PERFORMANCE: nodes=%d objects=%d orphans=%d process=%.3fms physics=%.3fms" % [
		node_count, object_count, orphan_count, maximum_process_seconds * 1000.0, maximum_physics_seconds * 1000.0
	])
	session.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.2).timeout
	SyntheticAudio.release_cached_streams()
	UiTranslations.release_registered()
	if failures.is_empty():
		print("SURVIVAL PERFORMANCE TEST PASSED")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _count_nodes(node: Node) -> int:
	var count: int = 1
	for child: Node in node.get_children():
		count += _count_nodes(child)
	return count
