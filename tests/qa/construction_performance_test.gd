extends SceneTree

const WORLD_SCENE: PackedScene = preload("res://scenes/survival/world_session.tscn")
const PIECE_COUNT: int = 250
const FUNCTIONAL_COUNT: int = 20


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var session: WorldSession = WORLD_SCENE.instantiate() as WorldSession
	root.add_child(session)
	var states: Array[Dictionary] = _make_building_states(session.construction_system.catalog)
	session.construction_system.restore_buildings(states)
	for _warmup_frame: int in 60:
		await physics_frame
	var maximum_process_seconds: float = 0.0
	var maximum_physics_seconds: float = 0.0
	for frame_index: int in 120:
		await physics_frame
		if frame_index == 0:
			continue
		maximum_process_seconds = maxf(
			maximum_process_seconds,
			Performance.get_monitor(Performance.TIME_PROCESS)
		)
		maximum_physics_seconds = maxf(
			maximum_physics_seconds,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		)
	var building_count: int = 0
	var functional_count: int = 0
	for child: Node in session.construction_system.get_children():
		if child is BuildingPiece:
			building_count += 1
			if (child as BuildingPiece).piece_data.functional_kind \
					!= BuildingPieceData.FunctionalKind.STRUCTURE:
				functional_count += 1
	var node_count: int = _count_nodes(session)
	var object_count: int = roundi(Performance.get_monitor(Performance.OBJECT_COUNT))
	var orphan_count: int = roundi(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var failures: Array[String] = []
	if building_count != PIECE_COUNT:
		failures.append("Construction performance scene did not restore 250 pieces.")
	if functional_count != FUNCTIONAL_COUNT:
		failures.append("Construction performance scene did not restore 20 functional objects.")
	if node_count > 1900:
		failures.append("Construction scene exceeded the 1900-node budget.")
	if object_count > 7000:
		failures.append("Construction scene exceeded the 7000-object budget.")
	if orphan_count > 12:
		failures.append("Construction scene produced unexpected orphan nodes.")
	if maximum_process_seconds > 0.025:
		failures.append("Construction process frame exceeded 25 ms.")
	if maximum_physics_seconds > 0.025:
		failures.append("Construction physics frame exceeded 25 ms.")
	print("CONSTRUCTION PERFORMANCE: pieces=%d functional=%d nodes=%d objects=%d orphans=%d process=%.3fms physics=%.3fms" % [
		building_count,
		functional_count,
		node_count,
		object_count,
		orphan_count,
		maximum_process_seconds * 1000.0,
		maximum_physics_seconds * 1000.0,
	])
	session.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.2).timeout
	SyntheticAudio.release_cached_streams()
	UiTranslations.release_registered()
	if failures.is_empty():
		print("CONSTRUCTION PERFORMANCE TEST PASSED")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _make_building_states(catalog: BuildingCatalog) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	var functional_ids: Array[StringName] = [
		&"door", &"chest", &"cauldron", &"rune_table", &"bed_altar", &"witchfire_hearth", &"ward_obelisk",
	]
	for index: int in PIECE_COUNT:
		var piece_id: StringName = &"foundation"
		var functional_state: Dictionary = {}
		if index < FUNCTIONAL_COUNT:
			piece_id = functional_ids[index % functional_ids.size()]
			if piece_id == &"ward_obelisk":
				functional_state = {"ward_fuel": 3}
			elif piece_id == &"door":
				functional_state = {"door_open": index % 2 == 0}
		assert(catalog.get_piece(piece_id) != null)
		states.append({
			"persistent_id": "perf_build_%04d" % index,
			"piece_id": String(piece_id),
			"position": {
				"x": float(index % 25) * 5.0,
				"y": 0.0,
				"z": float(index / 25) * 5.0,
			},
			"rotation_y": 0.0,
			"durability": 100.0,
			"support_level": BuildingPiece.SupportLevel.GROUNDED,
			"functional_state": functional_state,
		})
	return states


func _count_nodes(node: Node) -> int:
	var count: int = 1
	for child: Node in node.get_children():
		count += _count_nodes(child)
	return count
