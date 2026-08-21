extends GutTest

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player/player.tscn")
const CULTIST_SCENE: PackedScene = preload("res://scenes/enemies/cultist_enemy.tscn")


func test_cultist_bolt_damages_player_at_range() -> void:
	var world: Node3D = Node3D.new()
	add_child_autofree(world)
	_add_floor(world)
	var player: MagePlayer = PLAYER_SCENE.instantiate() as MagePlayer
	var cultist: CultistEnemy = CULTIST_SCENE.instantiate() as CultistEnemy
	player.position = Vector3(0.0, 0.0, -6.0)
	world.add_child(player)
	world.add_child(cultist)
	cultist.set_combat_target(player)
	var health_before: float = player.get_health_component().current_health

	assert_true(cultist.try_attack())
	for _frame: int in 50:
		await get_tree().physics_frame

	assert_eq(player.get_health_component().current_health, health_before - cultist.attack_damage)


func test_enemy_projectile_ignores_enemy_faction() -> void:
	var world: Node3D = Node3D.new()
	add_child_autofree(world)
	_add_floor(world)
	var player: MagePlayer = PLAYER_SCENE.instantiate() as MagePlayer
	var shooter: CultistEnemy = CULTIST_SCENE.instantiate() as CultistEnemy
	var ally: CultistEnemy = CULTIST_SCENE.instantiate() as CultistEnemy
	player.position = Vector3(0.0, 0.0, -7.0)
	ally.position = Vector3(0.0, 0.0, -3.0)
	world.add_child(player)
	world.add_child(shooter)
	world.add_child(ally)
	shooter.set_combat_target(player)
	var ally_health_before: float = ally.get_health_component().current_health

	assert_true(shooter.try_attack())
	for _frame: int in 65:
		await get_tree().physics_frame

	assert_eq(ally.get_health_component().current_health, ally_health_before)
	assert_lt(player.get_health_component().current_health, player.get_health_component().max_health)


func _add_floor(world: Node3D) -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(20.0, 0.5, 20.0)
	floor_shape.shape = box
	floor_shape.position.y = -0.25
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)
