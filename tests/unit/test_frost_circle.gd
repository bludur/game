extends GutTest

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/chaser_enemy.tscn")


func test_movement_modifiers_use_strongest_slow_and_restore() -> void:
	var modifier: MovementModifierComponent = MovementModifierComponent.new()
	add_child_autofree(modifier)
	modifier.add_modifier(1, 0.7)
	modifier.add_modifier(2, 0.45)
	assert_almost_eq(modifier.get_multiplier(), 0.45, 0.001)
	modifier.remove_modifier(2)
	assert_almost_eq(modifier.get_multiplier(), 0.7, 0.001)
	modifier.remove_modifier(1)
	assert_almost_eq(modifier.get_multiplier(), 1.0, 0.001)


func test_frost_circle_cast_spends_mana_and_slows_enemy() -> void:
	var world: Node3D = Node3D.new()
	add_child_autofree(world)
	var player: MagePlayer = PLAYER_SCENE.instantiate() as MagePlayer
	var enemy: ChaserEnemy = ENEMY_SCENE.instantiate() as ChaserEnemy
	world.add_child(player)
	enemy.position = Vector3(0.0, 0.0, -4.0)
	world.add_child(enemy)

	var loadout: SpellLoadout = player.get_spell_loadout()
	var caster: SpellCaster = player.get_spell_caster()
	var mana: ManaComponent = player.get_mana_component()
	var mana_before: float = mana.current_mana
	assert_true(loadout.select_slot(1))
	assert_true(caster.cast_at(enemy.global_position))
	assert_eq(mana.current_mana, mana_before - loadout.get_active_spell().mana_cost)

	for _frame: int in 4:
		await get_tree().physics_frame

	assert_almost_eq(
		enemy.get_movement_multiplier(),
		loadout.get_active_spell().movement_speed_multiplier,
		0.001
	)


func test_loadout_rejects_unknown_slot_without_changing_active_spell() -> void:
	var player: MagePlayer = PLAYER_SCENE.instantiate() as MagePlayer
	add_child_autofree(player)
	var loadout: SpellLoadout = player.get_spell_loadout()
	var original_spell: SpellData = loadout.get_active_spell()
	assert_false(loadout.select_slot(7))
	assert_same(loadout.get_active_spell(), original_spell)
