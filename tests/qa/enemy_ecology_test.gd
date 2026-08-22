extends SceneTree

const WORLD_SCENE: PackedScene = preload("res://scenes/survival/world_session.tscn")


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var failures: Array[String] = []
	var session: WorldSession = WORLD_SCENE.instantiate() as WorldSession
	root.add_child(session)
	for _frame: int in 5:
		await physics_frame
	session.player.global_position = Vector3.ZERO
	session.player.get_hurtbox_component().grant_invulnerability(20.0)
	session.player.get_corruption_component().add_corruption(80.0, &"qa_ecology")
	session.world_clock.apply_state({"normalized_time": 0.86, "day_number": 2})
	var warning_seen: Array[bool] = [false]
	session.threat_director.raid_warning.connect(
		func(_raid_type: ThreatDirector.RaidType, seconds: float) -> void:
			warning_seen[0] = seconds >= 5.0
	)
	session.threat_director._begin_raid(ThreatDirector.RaidType.SOUL_SIEGE, false, true)
	if not warning_seen[0] or session.threat_director.current_state != ThreatDirector.State.RAID_WARNING:
		failures.append("Soul Siege does not provide its authored advance warning.")
	session.threat_director._activate_pending_raid()
	session.threat_director.clear_runtime_enemies()
	var camera: Camera3D = session.get_viewport().get_camera_3d()
	var visible_point: Vector3 = camera.global_position - camera.global_basis.z * 30.0
	if session.threat_director.is_spawn_position_safe(visible_point) \
			or session.threat_director.is_spawn_position_safe(
			session.witchfire_hearth.global_position, true
		):
		failures.append("Spawn safety accepted a visible or ward-protected point.")
	session._on_threat_enemy_defeated(
		Vector3.ZERO, &"witchfire_core", &"hollow_hunter_anatomy"
	)
	if not session.grimoire.unlocked_knowledge.has(&"hollow_hunter_anatomy"):
		failures.append("Rare enemy trophy did not unlock its Grimoire knowledge.")
	var spawned_count: int = session.threat_director.force_ecology_group(8)
	if spawned_count != 8 or session.threat_director.get_active_enemy_count() != 8:
		failures.append("The eight-enemy ecology group did not spawn within its hard cap.")
	var unique_roles: Dictionary[StringName, bool] = {}
	for role_id: StringName in session.threat_director.get_active_role_ids():
		unique_roles[role_id] = true
	if unique_roles.size() != 6:
		failures.append("The ecology group does not expose all six readable combat roles.")
	var hunter_mark_found: bool = false
	for enemy_node: Node in session.get_node("ThreatHost").get_children():
		if enemy_node is ChaserEnemy:
			var chaser: ChaserEnemy = enemy_node as ChaserEnemy
			if chaser.ecology_role_id == &"hollow_elite_hunter":
				hunter_mark_found = chaser.get_node_or_null("Visuals/MutationMark") != null
	if not hunter_mark_found:
		failures.append("The elite hunter lacks a visible authored mutation mark.")
	var stimuli_seen: Dictionary[int, bool] = {}
	session.threat_director.stimulus_emitted.connect(
		func(kind: ThreatDirector.StimulusKind, _position: Vector3, _intensity: float) -> void:
			stimuli_seen[int(kind)] = true
	)
	for kind: int in ThreatDirector.StimulusKind.size():
		session.threat_director.notify_stimulus(
			kind as ThreatDirector.StimulusKind, Vector3.ZERO, 12.0
		)
	if stimuli_seen.size() != ThreatDirector.StimulusKind.size():
		failures.append("Enemy perception does not receive all four magic stimulus kinds.")
	var building_states: Array[Dictionary] = []
	for index: int in 6:
		building_states.append({
			"persistent_id": "raid_build_%02d" % index,
			"piece_id": "ward" if index == 0 else "foundation",
			"position": {"x": float(index * 3), "y": 0.0, "z": 0.0},
			"rotation_y": 0.0,
			"functional_state": {
				"ward_fuel": 3,
				"ward_burn_remaining": 120.0,
			} if index == 0 else {},
		})
	session.construction_system.restore_buildings(building_states)
	await physics_frame
	session.threat_director.force_raid(ThreatDirector.RaidType.SOUL_SIEGE)
	for _pulse: int in 20:
		session.threat_director._apply_raid_pressure()
	if session.threat_director.get_raid_damage_applied() > 90.001:
		failures.append("Raid pressure exceeded its authored building-damage cap.")
	for piece: BuildingPiece in session.construction_system.get_building_pieces():
		if piece.current_durability < 1.0:
			failures.append("A raid destroyed a building instead of leaving it repairable.")
	if not bool(session.world_state.raid_state.get("active", false)):
		failures.append("Active raid identity was not persisted for save/load recovery.")
	# Production raids stagger spawns over two-second evaluations. Give this forced
	# all-at-once stress setup the same path-initialization grace before measuring.
	for _warmup_frame: int in 90:
		await physics_frame
	var maximum_physics_seconds: float = 0.0
	var maximum_physics_frame: int = -1
	var physics_samples: Array[float] = []
	for frame_index: int in 120:
		await physics_frame
		if frame_index > 0:
			var physics_seconds: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
			physics_samples.append(physics_seconds)
			if physics_seconds > maximum_physics_seconds:
				maximum_physics_seconds = physics_seconds
				maximum_physics_frame = frame_index
	physics_samples.sort()
	var p95_index: int = clampi(ceili(float(physics_samples.size()) * 0.95) - 1, 0, physics_samples.size() - 1)
	var p95_physics_seconds: float = physics_samples[p95_index]
	if p95_physics_seconds > 0.025 or maximum_physics_seconds > 0.050:
		failures.append("Eight-enemy navigation/combat exceeded its p95 or emergency physics budget.")
	print("ENEMY ECOLOGY: enemies=%d roles=%d raid_damage=%.1f physics_p95=%.3fms max=%.3fms frame=%d" % [
		session.threat_director.get_active_enemy_count(),
		unique_roles.size(),
		session.threat_director.get_raid_damage_applied(),
		p95_physics_seconds * 1000.0,
		maximum_physics_seconds * 1000.0,
		maximum_physics_frame,
	])
	var persisted_raid: Dictionary = session.world_state.raid_state.duplicate(true)
	session.threat_director.sync_from_world_state()
	if session.threat_director.current_state != ThreatDirector.State.NIGHT_HUNT \
			or session.threat_director.get_active_enemy_count() != 0 \
			or session.world_state.raid_state != persisted_raid:
		failures.append("Raid save/load sync duplicated enemies or lost its active identity.")
	session.threat_director.clear_runtime_enemies()
	session.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.2).timeout
	SyntheticAudio.release_cached_streams()
	UiTranslations.release_registered()
	if failures.is_empty():
		print("ENEMY ECOLOGY TEST PASSED")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)
