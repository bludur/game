extends GutTest

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/chaser_enemy.tscn")


func test_enemy_melee_attack_damages_player_through_hurtbox() -> void:
	var world: Node3D = Node3D.new()
	add_child_autofree(world)

	var player: MagePlayer = PLAYER_SCENE.instantiate() as MagePlayer
	var enemy: ChaserEnemy = ENEMY_SCENE.instantiate() as ChaserEnemy
	world.add_child(player)
	enemy.position = Vector3(0.0, 0.0, -1.0)
	world.add_child(enemy)
	enemy.set_combat_target(player)

	var health: HealthComponent = player.get_health_component()
	var health_before: float = health.current_health
	assert_true(enemy.try_attack())
	assert_eq(health.current_health, health_before - enemy.attack_damage)


func test_enemy_hurtbox_uses_enemy_faction() -> void:
	var enemy: ChaserEnemy = ENEMY_SCENE.instantiate() as ChaserEnemy
	add_child_autofree(enemy)
	assert_true(enemy.get_hurtbox_component().belongs_to(&"enemy"))
	assert_false(enemy.get_hurtbox_component().belongs_to(&"player"))


func test_player_respawns_with_full_health_and_mana() -> void:
	var player: MagePlayer = PLAYER_SCENE.instantiate() as MagePlayer
	player.respawn_delay = 0.01
	add_child_autofree(player)
	player.get_mana_component().try_spend(30.0)
	player.get_health_component().take_damage(player.get_health_component().max_health)

	await get_tree().create_timer(0.05).timeout

	assert_eq(player.get_health_component().current_health, player.get_health_component().max_health)
	assert_eq(player.get_mana_component().current_mana, player.get_mana_component().max_mana)
