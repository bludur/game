extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const MODEL_PATHS: PackedStringArray = [
	"res://assets/models/mage_player.glb",
	"res://assets/models/shadow_chaser.glb",
	"res://assets/models/ember_cultist.glb",
	"res://assets/models/arena_floor.glb",
	"res://assets/models/arena_obelisk.glb",
	"res://assets/models/arena_altar.glb",
]


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var failures: Array[String] = []
	for model_path: String in MODEL_PATHS:
		if not ResourceLoader.exists(model_path, "PackedScene"):
			failures.append("Missing imported model: %s" % model_path)
			continue
		var model_scene: PackedScene = load(model_path) as PackedScene
		if model_scene == null:
			failures.append("Could not load model: %s" % model_path)
			continue
		var model: Node = model_scene.instantiate()
		root.add_child(model)
		if _count_meshes(model) == 0:
			failures.append("Model contains no meshes: %s" % model_path)
		model.queue_free()
	await process_frame

	var main: Node = MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	for character_path: NodePath in [
		NodePath("Player/Visuals/ModelRoot/MageModel"),
		NodePath("Player/CharacterAnimator"),
		NodePath("Arena/ArenaFloorVisual"),
		NodePath("ObstacleA/Visual"),
		NodePath("Decor/AltarNorth"),
	]:
		if main.get_node_or_null(character_path) == null:
			failures.append("Main scene is missing stylized node: %s" % character_path)
	main.queue_free()
	await process_frame

	if failures.is_empty():
		print("STYLIZED ASSETS TEST PASSED")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _count_meshes(node: Node) -> int:
	var count: int = 1 if node is MeshInstance3D else 0
	for child: Node in node.get_children():
		count += _count_meshes(child)
	return count
