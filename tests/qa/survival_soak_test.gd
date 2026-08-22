extends SceneTree

const WORLD_SCENE: PackedScene = preload("res://scenes/survival/world_session.tscn")
const SAVE_DIRECTORY: String = "res://.godot/survival_soak_saves/"


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var failures: Array[String] = []
	var session: WorldSession = WORLD_SCENE.instantiate() as WorldSession
	root.add_child(session)
	await process_frame
	var initial_orphans: int = roundi(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

	# Advance ninety logical minutes without waiting ninety wall-clock minutes.
	for simulated_second: int in 5400:
		session.world_clock._process(1.0)
		var night: bool = session.world_clock.is_night()
		session.player.get_corruption_component().update_exposure(1.0, night, false, false)
		if simulated_second % 600 == 599:
			session.player.get_corruption_component().cleanse(100.0, &"soak_reset")
	if session.world_clock.day_number < 8:
		failures.append("Accelerated ninety-minute clock simulation did not cross enough days.")

	var building_states: Array[Dictionary] = []
	for index: int in 150:
		building_states.append({
			"persistent_id": "soak_build_%04d" % index,
			"piece_id": "foundation",
			"position": {
				"x": float(index % 15) * 4.0 - 28.0,
				"y": 0.0,
				"z": float(index / 15) * 4.0 - 18.0,
			},
			"rotation_y": float(index % 4) * PI * 0.5,
		})
	session.construction_system.restore_buildings(building_states)
	await process_frame
	if _count_buildings(session.construction_system) != 150:
		failures.append("Construction restore did not produce 150 persistent pieces.")

	for hunt_index: int in 3:
		session.threat_director.force_night_hunt()
		if session.threat_director.get_active_enemy_count() <= 0:
			failures.append("Night hunt %d did not spawn threats." % [hunt_index + 1])
		session.threat_director.clear_runtime_enemies()
		await process_frame

	for death_index: int in 3:
		session.get_player_inventory().add_item(session.item_catalog.get_item(&"gravewood"), 6)
		session.player.get_health_component().take_damage(10000.0)
		await create_timer(2.1).timeout
		if not session.player.get_health_component().is_alive():
			failures.append("Death cycle %d did not respawn the player." % [death_index + 1])

	var save_service: SaveGameService = SaveGameService.new()
	save_service.save_directory = SAVE_DIRECTORY
	root.add_child(save_service)
	save_service.delete_save(0)
	var maximum_save_msec: int = 0
	for save_cycle: int in 3:
		session.world_state.set_progression_flag(StringName("soak_save_%d" % save_cycle))
		var started_msec: int = Time.get_ticks_msec()
		if not save_service.save_game(session, 0):
			failures.append("Save cycle %d failed." % [save_cycle + 1])
		maximum_save_msec = maxi(maximum_save_msec, Time.get_ticks_msec() - started_msec)
		session.player.global_position += Vector3(1, 0, 1)
		if not save_service.load_game(session, 0):
			failures.append("Load cycle %d failed." % [save_cycle + 1])
		await process_frame
	if maximum_save_msec > 150:
		failures.append("Save operation exceeded the 150 ms target.")
	save_service.delete_save(0)

	var final_orphans: int = roundi(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	if final_orphans > initial_orphans:
		failures.append("Accelerated soak test leaked orphan nodes.")
	print("SURVIVAL SOAK: logical_seconds=5400 buildings=150 deaths=3 hunts=3 saves=3 max_save=%dms orphans=%d" % [
		maximum_save_msec, final_orphans
	])
	session.queue_free()
	save_service.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.2).timeout
	SyntheticAudio.release_cached_streams()
	UiTranslations.release_registered()
	if failures.is_empty():
		print("SURVIVAL SOAK TEST PASSED")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _count_buildings(host: ConstructionSystem) -> int:
	var count: int = 0
	for child: Node in host.get_children():
		if child is BuildingPiece and not child.is_queued_for_deletion():
			count += 1
	return count
