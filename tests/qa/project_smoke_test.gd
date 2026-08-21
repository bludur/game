extends SceneTree

const MAIN_SCENE_PATH: String = "res://scenes/main/main.tscn"
const SPELL_PATH: String = "res://resources/spells/arcane_bolt.tres"


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var failures: Array[String] = []
	var feature_tags: PackedStringArray = ProjectSettings.get_setting(
		"application/config/features",
		PackedStringArray()
	) as PackedStringArray
	if not feature_tags.has("Forward Plus"):
		failures.append("Forward Plus is not selected in project features.")
	if not bool(ProjectSettings.get_setting("physics/common/physics_interpolation", false)):
		failures.append("Physics interpolation is disabled.")

	var main_scene: PackedScene = load(MAIN_SCENE_PATH) as PackedScene
	if main_scene == null:
		failures.append("Main scene could not be loaded.")
	else:
		var main_instance: Node = main_scene.instantiate()
		root.add_child(main_instance)
		await process_frame
		await physics_frame

		var player: Node = get_first_node_in_group(&"player")
		if player == null:
			failures.append("Player group has no member.")
		if root.get_camera_3d() == null:
			failures.append("No active Camera3D was found.")

		main_instance.queue_free()
		await process_frame

	var spell: Resource = load(SPELL_PATH)
	if spell == null:
		failures.append("Arcane Bolt resource could not be loaded.")
	elif not bool(spell.call("is_valid_definition")):
		failures.append("Arcane Bolt definition is invalid.")

	if failures.is_empty():
		print("SMOKE TEST PASSED")
		quit(0)
		return

	for failure: String in failures:
		push_error(failure)
	quit(1)
