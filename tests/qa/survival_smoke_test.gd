extends SceneTree

const WORLD_SCENE: PackedScene = preload("res://scenes/survival/world_session.tscn")


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var failures: Array[String] = []
	var session: WorldSession = WORLD_SCENE.instantiate() as WorldSession
	root.add_child(session)
	await process_frame
	await physics_frame
	if session.get_region_id() != &"ashen_grove":
		failures.append("Unexpected survival region id.")
	if session.get_player_inventory().capacity != 24:
		failures.append("Survival inventory does not expose 24 slots.")
	if session.item_catalog == null or not session.item_catalog.is_valid_catalog() \
			or session.item_catalog.items.size() != 16:
		failures.append("Survival item catalog is invalid or incomplete.")
	if session.crafting_system.catalog.recipes.size() != 12:
		failures.append("Expected twelve authored recipes.")
	if session.ritual_system.catalog.rituals.size() != 6:
		failures.append("Expected six authored rituals.")
	if session.construction_system.catalog.pieces.size() != 9:
		failures.append("Expected nine authored building pieces.")
	var resources: Array[ResourceNode] = session.region.get_persistent_resources()
	if resources.size() < 10:
		failures.append("Ashen Grove has too few authored resource nodes.")
	var persistent_ids: Dictionary[StringName, bool] = {}
	for resource_node: ResourceNode in resources:
		if resource_node.persistent_id.is_empty() or persistent_ids.has(resource_node.persistent_id):
			failures.append("Persistent resource ids are missing or duplicated.")
		persistent_ids[resource_node.persistent_id] = true
	var camera: Camera3D = root.get_camera_3d()
	if camera == null or camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		failures.append("Survival camera is missing or not orthographic.")
	if session.survival_hud == null or session.survival_tutorial == null:
		failures.append("Survival HUD or contextual tutorial is missing.")
	var inventory: InventoryComponent = session.get_player_inventory()
	inventory.add_item(session.item_catalog.get_item(&"dusk_herb"), 2)
	inventory.add_item(session.item_catalog.get_item(&"moonstone"), 1)
	if not session.crafting_system.craft(&"brew_clear_root"):
		failures.append("Starting survival recipe could not be crafted.")
	if inventory.get_item_count(&"corruption_draught") != 1:
		failures.append("Crafted result was not placed in inventory.")
	var encoded_snapshot: String = JSON.stringify(session.serialize_game())
	var decoded_snapshot: Variant = JSON.parse_string(encoded_snapshot)
	if decoded_snapshot is not Dictionary:
		failures.append("Survival snapshot is not JSON compatible.")
	var node_count: int = _count_nodes(session)
	if node_count > 900:
		failures.append("Survival scene exceeded the 900-node prototype budget.")
	print("SURVIVAL SMOKE: resources=%d nodes=%d items=%d" % [
		resources.size(), node_count, session.item_catalog.items.size()
	])
	session.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.2).timeout
	SyntheticAudio.release_cached_streams()
	UiTranslations.release_registered()
	if failures.is_empty():
		print("SURVIVAL SMOKE TEST PASSED")
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
