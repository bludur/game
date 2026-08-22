extends SceneTree

const WORLD_SCENE: PackedScene = preload("res://scenes/survival/world_session.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var session: WorldSession = WORLD_SCENE.instantiate() as WorldSession
	root.add_child(session)
	await process_frame
	for item: ItemData in session.item_catalog.items:
		if not item.is_valid_definition():
			failures.append("Invalid item definition: %s" % item.item_id)
	var ashen_building: Dictionary = _building_state(
		&"build_9001_foundation", Vector3(8.0, 0.0, 8.0)
	)
	session.construction_system.restore_buildings([ashen_building])
	session.world_state.set_progression_flag(&"matriarch_defeated")
	session.get_player_inventory().add_item(session.item_catalog.get_item(&"portal_focus"), 1)
	if not session.request_region_transition(&"moonbound_expanse", &"portal_focus"):
		failures.append("Transition to Moonbound Expanse was rejected.")
	await process_frame
	await physics_frame
	if session.get_region_id() != &"moonbound_expanse":
		failures.append("Moonbound region did not become active.")
	if session.world_state.region_tier != 3:
		failures.append("Moonbound region did not restore its tier-three threat level.")
	if session.region.get_pois().size() != 5 or session.region.get_persistent_resources().size() != 12:
		failures.append("Moonbound authored POI/resource counts are incomplete.")
	var moon_building: Dictionary = _building_state(
		&"build_9002_foundation", Vector3(-8.0, 0.0, 18.0)
	)
	session.construction_system.restore_buildings([moon_building])
	var exposure_before: float = session.cold_exposure.current_exposure
	session.cold_exposure.advance(5.0, true, false)
	if session.cold_exposure.current_exposure <= exposure_before:
		failures.append("Moon cold did not accumulate outside protection.")
	var moonbound: MoonboundExpanse = session.region as MoonboundExpanse
	var inventory: InventoryComponent = session.get_player_inventory()
	inventory.add_item(session.item_catalog.get_item(&"nightglass"), 2)
	inventory.add_item(session.item_catalog.get_item(&"moonfrost_crystal"), 2)
	moonbound.call("_on_ritual_requested", session.player)
	if not session.world_state.has_ritual_flag(&"moon_eclipse_path_open"):
		failures.append("Moon regional ritual did not open the sanctum path.")
	if not session.request_region_transition(&"ashen_grove"):
		failures.append("Return transition to Ashen Grove was rejected.")
	await process_frame
	if session.get_region_id() != &"ashen_grove":
		failures.append("Ashen Grove did not restore after return transition.")
	if session.region.get_pois().size() != 12 or not session.witchfire_hearth.is_inside_tree():
		failures.append("Ashen Grove auxiliary state was not restored.")
	if not _has_building(session, &"build_9001_foundation"):
		failures.append("Ashen Grove building state was not restored after return.")
	if not session.world_state.region_states.has(&"moonbound_expanse"):
		failures.append("Moonbound region state was not captured.")
	if not session.request_region_transition(&"moonbound_expanse", &"portal_focus"):
		failures.append("Second Moonbound transition was rejected.")
	await process_frame
	if not _has_building(session, &"build_9002_foundation"):
		failures.append("Moonbound building state was not restored on revisit.")
	if not session.world_state.has_ritual_flag(&"moon_eclipse_path_open"):
		failures.append("Moon ritual state was lost on revisit.")
	if not session.request_region_transition(&"ashen_grove"):
		failures.append("Final return to Ashen Grove was rejected.")
	await process_frame
	print("MOONBOUND REGION: items=%d recipes=%d regions=%d cold=%.1f" % [
		session.item_catalog.items.size(), session.crafting_system.catalog.recipes.size(),
		session.world_state.region_states.size(), session.cold_exposure.current_exposure,
	])
	session.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.2).timeout
	SyntheticAudio.release_cached_streams()
	UiTranslations.release_registered()
	if failures.is_empty():
		print("MOONBOUND REGION TEST PASSED")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _building_state(persistent_id: StringName, building_position: Vector3) -> Dictionary:
	return {
		"persistent_id": String(persistent_id),
		"piece_id": "foundation",
		"position": {
			"x": building_position.x,
			"y": building_position.y,
			"z": building_position.z,
		},
		"rotation_y": 0.0,
		"durability": 180.0,
		"support_level": 0,
		"functional_state": {},
	}


func _has_building(session: WorldSession, persistent_id: StringName) -> bool:
	for piece: BuildingPiece in session.construction_system.get_building_pieces():
		if piece.persistent_id == persistent_id:
			return true
	return false
