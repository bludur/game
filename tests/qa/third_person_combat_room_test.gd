extends SceneTree

const ROOM_SCENE: PackedScene = preload("res://tests/visual/third_person_combat_room.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var room: ThirdPersonCombatRoom = ROOM_SCENE.instantiate() as ThirdPersonCombatRoom
	root.add_child(room)
	await process_frame
	await physics_frame
	var failures: Array[String] = []
	if room.get_combat_role_count() != 3:
		failures.append("Combat room did not activate all three enemy roles.")
	if get_nodes_in_group(&"combat_room_cover").size() < 2:
		failures.append("Combat room requires at least two authored cover objects.")
	if get_nodes_in_group(&"combat_room_height").is_empty():
		failures.append("Combat room requires an elevated combat surface.")
	if room.chaser.attack_telegraph == null or room.cultist.attack_telegraph == null:
		failures.append("Standard enemy roles are missing telegraph definitions.")
	if room.player.get_ward_component() == null:
		failures.append("Player ward component is missing from the combat room.")
	room.queue_free()
	await process_frame
	SyntheticAudio.release_cached_streams()
	if failures.is_empty():
		print("THIRD_PERSON_COMBAT_ROOM_TEST: PASS")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)
