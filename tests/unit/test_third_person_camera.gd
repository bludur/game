extends GutTest

const CAMERA_SCENE: PackedScene = preload("res://scenes/cameras/third_person_camera_rig.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player/player.tscn")
const WORLD_SCENE: PackedScene = preload("res://scenes/survival/world_session.tscn")


func before_each() -> void:
	SurvivalInputProfile.ensure_actions()


func after_each() -> void:
	Input.action_release(&"move_forward")
	Input.action_release(&"move_right")
	Input.action_release(&"sprint")
	Input.action_release(&"jump")
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


func test_valheim_input_profile_uses_space_for_jump_and_alt_for_dodge() -> void:
	assert_true(_has_physical_key(&"sprint", KEY_SHIFT))
	assert_true(_has_physical_key(&"jump", KEY_SPACE))
	assert_true(_has_physical_key(&"dash", KEY_ALT))
	assert_false(_has_physical_key(&"dash", KEY_SPACE))
	assert_false(_has_physical_key(&"dash", KEY_SHIFT))


func test_sprint_increases_player_horizontal_speed() -> void:
	var world: Node3D = Node3D.new()
	add_child_autofree(world)
	_add_floor(world)
	var player: MagePlayer = PLAYER_SCENE.instantiate() as MagePlayer
	world.add_child(player)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	for _frame: int in 30:
		await get_tree().physics_frame
	var horizontal_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	var controller: PlayerController = player.get_node("PlayerController") as PlayerController
	assert_gt(horizontal_speed, controller.move_speed * 1.3)
	assert_lt(player.get_stamina_component().current_stamina, player.get_stamina_component().max_stamina)


func test_jump_spends_stamina_and_applies_upward_velocity() -> void:
	var world: Node3D = Node3D.new()
	add_child_autofree(world)
	_add_floor(world)
	var player: MagePlayer = PLAYER_SCENE.instantiate() as MagePlayer
	world.add_child(player)
	for _frame: int in 3:
		await get_tree().physics_frame
	var stamina_before: float = player.get_stamina_component().current_stamina
	var controller: PlayerController = player.get_node("PlayerController") as PlayerController
	assert_true(controller.request_jump())
	await get_tree().physics_frame
	assert_gt(player.velocity.y, 0.0)
	assert_almost_eq(
		player.get_stamina_component().current_stamina,
		stamina_before - controller.jump_stamina_cost,
		0.2
	)


func test_coyote_time_allows_jump_just_after_leaving_a_ledge() -> void:
	var world: Node3D = Node3D.new()
	add_child_autofree(world)
	_add_floor_with_size(world, Vector3(1.5, 0.4, 8.0))
	var player: MagePlayer = PLAYER_SCENE.instantiate() as MagePlayer
	world.add_child(player)
	for _frame: int in 3:
		await get_tree().physics_frame
	Input.action_press(&"move_right")
	var left_ledge: bool = false
	for _frame: int in 45:
		await get_tree().physics_frame
		if not player.is_on_floor():
			left_ledge = true
			break
	Input.action_release(&"move_right")
	assert_true(left_ledge)
	var controller: PlayerController = player.get_node("PlayerController") as PlayerController
	assert_true(controller.request_jump())
	await get_tree().physics_frame
	assert_gt(player.velocity.y, 0.0)


func test_jump_buffer_fires_when_pressed_just_before_landing() -> void:
	var world: Node3D = Node3D.new()
	add_child_autofree(world)
	_add_floor(world)
	var player: MagePlayer = PLAYER_SCENE.instantiate() as MagePlayer
	player.position.y = 1.5
	world.add_child(player)
	var controller: PlayerController = player.get_node("PlayerController") as PlayerController
	var jump_queued: bool = false
	for _frame: int in 45:
		await get_tree().physics_frame
		if not player.is_on_floor() and player.position.y < 0.35:
			jump_queued = controller.request_jump()
			break
	assert_true(jump_queued)
	var buffered_jump_fired: bool = false
	for _frame: int in 18:
		await get_tree().physics_frame
		if player.velocity.y > 1.0:
			buffered_jump_fired = true
			break
	assert_true(buffered_jump_fired)


func test_camera_preferences_apply_fov_inversion_and_shoulder_side() -> void:
	var rig: ThirdPersonCameraRig = CAMERA_SCENE.instantiate() as ThirdPersonCameraRig
	add_child_autofree(rig)
	rig.apply_settings(0.006, true, 82.0, true)
	assert_almost_eq(rig.mouse_sensitivity, 0.006, 0.0001)
	assert_true(rig.invert_y)
	assert_almost_eq(rig.get_camera().fov, 82.0, 0.001)
	assert_true(rig.is_left_shoulder())
	for _frame: int in 20:
		await get_tree().process_frame
	assert_lt(rig.get_shoulder_offset(), 0.0)


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


func _add_floor(parent: Node3D) -> void:
	_add_floor_with_size(parent, Vector3(20.0, 0.4, 20.0))


func _add_floor_with_size(parent: Node3D, size: Vector3) -> void:
	var floor: StaticBody3D = StaticBody3D.new()
	floor.collision_layer = 1
	floor.collision_mask = 0
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	floor.position.y = -0.2
	floor.add_child(collision)
	parent.add_child(floor)
