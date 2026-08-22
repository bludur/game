extends GutTest

const CAMERA_SCENE: PackedScene = preload("res://scenes/cameras/third_person_camera_rig.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player/player.tscn")
const WORLD_SCENE: PackedScene = preload("res://scenes/survival/world_session.tscn")


func before_each() -> void:
	SurvivalInputProfile.ensure_actions()


func after_each() -> void:
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_camera_rig_is_perspective_and_avoids_world_geometry() -> void:
	var target: Node3D = Node3D.new()
	target.add_to_group(&"player")
	add_child_autofree(target)
	var rig: ThirdPersonCameraRig = CAMERA_SCENE.instantiate() as ThirdPersonCameraRig
	add_child_autofree(rig)
	await get_tree().process_frame

	assert_eq(rig.get_camera().projection, Camera3D.PROJECTION_PERSPECTIVE)
	assert_eq(rig.get_spring_arm().collision_mask, 1)
	assert_true(rig.get_camera().current)


func test_camera_zoom_is_clamped_to_authored_range() -> void:
	var rig: ThirdPersonCameraRig = CAMERA_SCENE.instantiate() as ThirdPersonCameraRig
	add_child_autofree(rig)
	for _step: int in 20:
		rig.adjust_zoom(-1.0)
	assert_almost_eq(rig.get_desired_distance(), rig.minimum_distance, 0.001)
	for _step: int in 40:
		rig.adjust_zoom(1.0)
	assert_almost_eq(rig.get_desired_distance(), rig.maximum_distance, 0.001)


func test_valheim_input_profile_uses_shift_for_sprint_and_space_for_dodge() -> void:
	assert_true(_has_physical_key(&"sprint", KEY_SHIFT))
	assert_true(_has_physical_key(&"dash", KEY_SPACE))
	assert_false(_has_physical_key(&"dash", KEY_SHIFT))


func test_sprint_increases_player_horizontal_speed() -> void:
	var world: Node3D = Node3D.new()
	add_child_autofree(world)
	var player: MagePlayer = PLAYER_SCENE.instantiate() as MagePlayer
	world.add_child(player)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	for _frame: int in 30:
		await get_tree().physics_frame
	var horizontal_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	var controller: PlayerController = player.get_node("PlayerController") as PlayerController
	assert_gt(horizontal_speed, controller.move_speed * 1.3)


func test_session_pause_releases_pointer_and_hides_crosshair() -> void:
	var session: WorldSession = WORLD_SCENE.instantiate() as WorldSession
	add_child_autofree(session)
	await get_tree().process_frame
	var crosshair: Label = session.survival_hud.get_node("Root/Crosshair") as Label
	assert_true(session.third_person_camera.are_controls_enabled())
	assert_true(crosshair.visible)
	session.set_session_paused(true)
	assert_false(session.third_person_camera.are_controls_enabled())
	assert_false(crosshair.visible)
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE)


func _has_physical_key(action: StringName, key: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == key:
			return true
	return false
