extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://scenes/main/arena_run.tscn")


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var main_instance: Node = MAIN_SCENE.instantiate()
	root.add_child(main_instance)
	await process_frame
	var run_director: RunDirector = main_instance.get_node_or_null("RunDirector") as RunDirector
	if run_director != null:
		run_director.start_new_run(true)
	await physics_frame

	var player: MagePlayer = get_first_node_in_group(&"player") as MagePlayer
	var enemy: ChaserEnemy = get_first_node_in_group(&"enemy") as ChaserEnemy
	if player == null or enemy == null:
		push_error("Enemy chase test requires one MagePlayer and one ChaserEnemy.")
		await _cleanup(main_instance)
		quit(1)
		return

	enemy.global_position = Vector3(5.0, 0.0, -4.0)
	enemy.reset_physics_interpolation()
	enemy.set_combat_target(player)
	var start_distance: float = enemy.global_position.distance_to(player.global_position)
	var closest_distance: float = start_distance
	var starting_health: float = player.get_health_component().current_health

	for _frame: int in 240:
		await physics_frame
		closest_distance = minf(
			closest_distance,
			enemy.global_position.distance_to(player.global_position)
		)

	var failures: Array[String] = []
	if closest_distance >= start_distance - 1.0:
		failures.append("ChaserEnemy did not move meaningfully toward the player.")
	if player.get_health_component().current_health >= starting_health:
		failures.append("ChaserEnemy reached no successful melee attack within four seconds.")

	await _cleanup(main_instance)

	if failures.is_empty():
		print("ENEMY CHASE TEST PASSED")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _cleanup(main_instance: Node) -> void:
	main_instance.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.2).timeout
	SyntheticAudio.release_cached_streams()
