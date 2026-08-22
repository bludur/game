extends SceneTree

const WORLD_SCENE: PackedScene = preload("res://scenes/survival/world_session.tscn")
const SAVE_DIRECTORY: String = "res://.godot/alpha_two_region_soak_saves/"
const PIECES_PER_REGION: int = 125
const TRANSITION_COUNT: int = 5
const SAVE_LOAD_COUNT: int = 5
const DEATH_COUNT: int = 5


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var failures: Array[String] = []
	var session: WorldSession = WORLD_SCENE.instantiate() as WorldSession
	root.add_child(session)
	await process_frame
	var initial_orphans: int = roundi(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	session.world_state.set_progression_flag(&"matriarch_defeated")
	session.get_player_inventory().add_item(session.item_catalog.get_item(&"portal_focus"), 1)
	session.construction_system.restore_buildings(_building_states(10000, PIECES_PER_REGION))
	await process_frame

	var maximum_transition_msec: int = 0
	for transition_index: int in TRANSITION_COUNT:
		var target_region: StringName = &"moonbound_expanse" \
			if session.get_region_id() == &"ashen_grove" else &"ashen_grove"
		var transition_started: int = Time.get_ticks_msec()
		if not session.request_region_transition(target_region, &"portal_focus"):
			failures.append("Region transition %d was rejected." % [transition_index + 1])
			break
		await process_frame
		await process_frame
		maximum_transition_msec = maxi(
			maximum_transition_msec,
			Time.get_ticks_msec() - transition_started
		)
		if session.get_region_id() != target_region:
			failures.append("Region transition %d activated the wrong region." % [transition_index + 1])
		if transition_index == 0:
			session.construction_system.restore_buildings(
				_building_states(20000, PIECES_PER_REGION)
			)
			await process_frame
		elif _active_building_count(session) != PIECES_PER_REGION:
			failures.append("Region %s did not restore %d buildings." % [
				target_region, PIECES_PER_REGION,
			])

	# Capture the fifth transition's active Moonbound state before inspecting both regions.
	session.serialize_game()
	if _total_persisted_buildings(session) != PIECES_PER_REGION * 2:
		failures.append("Two region states did not preserve all 250 buildings.")
	if maximum_transition_msec > 5000:
		failures.append("A region transition exceeded the five-second SSD target.")

	var save_service: SaveGameService = SaveGameService.new()
	save_service.save_directory = SAVE_DIRECTORY
	root.add_child(save_service)
	save_service.delete_save(0)
	var maximum_save_msec: int = 0
	for save_cycle: int in SAVE_LOAD_COUNT:
		session.world_state.set_progression_flag(StringName("alpha_save_%d" % save_cycle))
		var save_started: int = Time.get_ticks_msec()
		if not save_service.save_game(session, 0):
			failures.append("Save cycle %d failed." % [save_cycle + 1])
		maximum_save_msec = maxi(maximum_save_msec, Time.get_ticks_msec() - save_started)
		session.player.global_position += Vector3(3.0, 0.0, -2.0)
		if not save_service.load_game(session, 0):
			failures.append("Load cycle %d failed." % [save_cycle + 1])
		await process_frame
		await process_frame
		if session.get_region_id() != &"moonbound_expanse" \
				or _active_building_count(session) != PIECES_PER_REGION:
			failures.append("Save/load cycle %d lost the active Moonbound state." % [save_cycle + 1])
	if maximum_save_msec > 150:
		failures.append("Save operation exceeded the 150 ms target.")

	for death_index: int in DEATH_COUNT:
		session.get_player_inventory().add_item(session.item_catalog.get_item(&"gravewood"), 2)
		session.player.get_health_component().take_damage(10000.0)
		await create_timer(2.1).timeout
		if not session.player.get_health_component().is_alive():
			failures.append("Death cycle %d did not respawn the player." % [death_index + 1])

	save_service.delete_save(0)
	var final_orphans: int = roundi(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	if final_orphans > initial_orphans:
		failures.append("Two-region alpha soak leaked orphan nodes.")
	print(
		(
			"ALPHA TWO-REGION SOAK: transitions=%d max_transition=%dms buildings=%d " \
			+ "save_load=%d max_save=%dms deaths=%d orphans=%d"
		) % [
			TRANSITION_COUNT, maximum_transition_msec, _total_persisted_buildings(session),
			SAVE_LOAD_COUNT, maximum_save_msec, DEATH_COUNT, final_orphans,
		]
	)
	session.queue_free()
	save_service.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.2).timeout
	SyntheticAudio.release_cached_streams()
	UiTranslations.release_registered()
	if failures.is_empty():
		print("ALPHA TWO-REGION SOAK TEST PASSED")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _building_states(first_number: int, count: int) -> Array:
	var states: Array[Dictionary] = []
	for index: int in count:
		states.append({
			"persistent_id": "build_%d_foundation" % [first_number + index],
			"piece_id": "foundation",
			"position": {
				"x": float(index % 13) * 4.0 - 24.0,
				"y": 0.0,
				"z": float(index / 13) * 4.0 - 18.0,
			},
			"rotation_y": float(index % 4) * PI * 0.5,
			"durability": 180.0,
			"support_level": 0,
			"functional_state": {},
		})
	return states


func _active_building_count(session: WorldSession) -> int:
	return session.construction_system.get_building_pieces().size()


func _total_persisted_buildings(session: WorldSession) -> int:
	var total: int = 0
	for region_id: StringName in [&"ashen_grove", &"moonbound_expanse"]:
		var state: Dictionary = session.world_state.get_region_state(region_id)
		total += (state.get("buildings", []) as Array).size()
	return total
