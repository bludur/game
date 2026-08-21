extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")


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
	for _frame: int in 180:
		await physics_frame

	var node_count: int = _count_nodes(main)
	var object_count: int = roundi(Performance.get_monitor(Performance.OBJECT_COUNT))
	var orphan_count: int = roundi(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var process_seconds: float = Performance.get_monitor(Performance.TIME_PROCESS)
	var physics_seconds: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	print(
		"PERFORMANCE SMOKE: nodes=%d objects=%d orphans=%d process=%.3fms physics=%.3fms"
		% [node_count, object_count, orphan_count, process_seconds * 1000.0, physics_seconds * 1000.0]
	)
	var failures: Array[String] = []
	if node_count > 500:
		failures.append("Main scene exceeded the 500-node prototype budget.")
	if object_count > 2500:
		failures.append("Object count exceeded the 2500-object prototype budget.")
	if orphan_count > 10:
		failures.append("Unexpected orphan node growth was detected.")
	main.queue_free()
	await process_frame
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
