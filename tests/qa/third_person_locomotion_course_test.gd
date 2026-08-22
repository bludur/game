extends SceneTree

const COURSE_SCENE: PackedScene = preload("res://tests/visual/third_person_locomotion_course.tscn")


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	SurvivalInputProfile.ensure_actions()
	var failures: Array[String] = []
	var course: Node3D = COURSE_SCENE.instantiate() as Node3D
	root.add_child(course)
	for _frame: int in 6:
		await physics_frame
		await process_frame
	var player: MagePlayer = course.get_node_or_null("Player") as MagePlayer
	var camera_rig: ThirdPersonCameraRig = course.get_node_or_null("ThirdPersonCameraRig") as ThirdPersonCameraRig
	for required_path: NodePath in [
		NodePath("CameraBackWall"), NodePath("DodgeWall"), NodePath("ColumnLeft"),
		NodePath("ColumnRight"), NodePath("LowCeiling"), NodePath("Slope"), NodePath("Stairs"),
	]:
		if course.get_node_or_null(required_path) == null:
			failures.append("Locomotion course is missing %s." % required_path)
	if player == null or camera_rig == null:
		failures.append("Locomotion course is missing the player or camera rig.")
	else:
		if camera_rig.get_spring_arm().get_hit_length() >= camera_rig.get_spring_arm().spring_length - 0.05:
			failures.append("Spring arm did not retract in front of the authored camera wall.")
		var stamina_before: float = player.get_stamina_component().current_stamina
		if not player.request_dash(Vector3.RIGHT):
			failures.append("Directional dodge could not start in the locomotion course.")
		for _frame: int in 24:
			await physics_frame
		if player.global_position.x >= 1.65:
			failures.append("Directional dodge crossed the collision wall.")
		if player.get_stamina_component().current_stamina >= stamina_before:
			failures.append("Directional dodge did not spend stamina.")
	course.queue_free()
	await process_frame
	await process_frame
	SyntheticAudio.release_cached_streams()
	if failures.is_empty():
		print("THIRD-PERSON LOCOMOTION COURSE PASSED")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)
