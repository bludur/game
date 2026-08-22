extends GutTest

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player/player.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/main/arena_run.tscn")


func test_dash_moves_player_and_grants_temporary_invulnerability() -> void:
	var world: Node3D = Node3D.new()
	add_child_autofree(world)
	var player: MagePlayer = PLAYER_SCENE.instantiate() as MagePlayer
	world.add_child(player)
	var start_x: float = player.global_position.x

	assert_true(player.request_dash(Vector3.RIGHT))
	assert_true(player.get_combat_state_component().is_dodging())
	assert_true(player.get_hurtbox_component().is_invulnerable())
	assert_false(player.get_hurtbox_component().receive_hit(10.0))

	for _frame: int in 10:
		await get_tree().physics_frame

	assert_gt(player.global_position.x, start_x + 1.0)
	assert_gt(player.get_dash_component().get_cooldown_remaining(), 0.0)
	assert_false(player.request_dash(Vector3.RIGHT))


func test_dash_uses_character_collision_instead_of_crossing_obstacle() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	var player: MagePlayer = get_tree().get_first_node_in_group(&"player") as MagePlayer
	player.global_position = Vector3(1.8, 0.0, -2.0)
	player.reset_physics_interpolation()
	assert_true(player.request_dash(Vector3.RIGHT))

	for _frame: int in 24:
		await get_tree().physics_frame

	assert_lt(player.global_position.x, 2.5)
