extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://scenes/main/arena_run.tscn")


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	var director: RunDirector = main.get_node("RunDirector") as RunDirector
	var waves: WaveDirector = main.get_node("WaveDirector") as WaveDirector
	var player: MagePlayer = get_first_node_in_group(&"player") as MagePlayer
	director.start_new_run(true)
	waves.stop_and_clear()
	waves.start_wave(2)
	player.get_hurtbox_component().grant_invulnerability(10.0)
	# Navigation-map synchronization and imported-resource setup are startup work,
	# so the combat budget begins after a short deterministic warmup.
	for _warmup_frame: int in 120:
		await physics_frame
	var maximum_process_seconds: float = 0.0
	var maximum_physics_seconds: float = 0.0
	var maximum_physics_frame_index: int = -1
	for frame_index: int in 180:
		await physics_frame
		# Performance monitors expose the previous synchronization sample on
		# the first read; discard it so startup is not mislabeled as combat.
		if frame_index == 0:
			continue
		maximum_process_seconds = maxf(
			maximum_process_seconds,
			Performance.get_monitor(Performance.TIME_PROCESS)
		)
		var physics_seconds: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		if physics_seconds > maximum_physics_seconds:
			maximum_physics_seconds = physics_seconds
			maximum_physics_frame_index = frame_index

	var node_count: int = _count_nodes(main)
	var object_count: int = roundi(Performance.get_monitor(Performance.OBJECT_COUNT))
	var orphan_count: int = roundi(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	print(
		"PERFORMANCE SMOKE: nodes=%d objects=%d orphans=%d max_process=%.3fms max_physics=%.3fms physics_peak_frame=%d"
		% [node_count, object_count, orphan_count, maximum_process_seconds * 1000.0, maximum_physics_seconds * 1000.0, maximum_physics_frame_index]
	)
	var failures: Array[String] = []
	if node_count > 500:
		failures.append("Main scene exceeded the 500-node prototype budget.")
	if object_count > 2500:
		failures.append("Object count exceeded the 2500-object prototype budget.")
	if orphan_count > 10:
		failures.append("Unexpected orphan node growth was detected.")
	if maximum_process_seconds > 0.025:
		failures.append("Main-thread frame time exceeded the 25 ms smoke budget.")
	if maximum_physics_seconds > 0.025:
		failures.append("Physics frame time exceeded the 25 ms smoke budget.")
	main.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.2).timeout
	SyntheticAudio.release_cached_streams()
	if failures.is_empty():
		print("PERFORMANCE SMOKE TEST PASSED")
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
