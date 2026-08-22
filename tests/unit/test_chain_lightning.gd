extends GutTest

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player/player.tscn")
const TARGET_SCENE: PackedScene = preload("res://scenes/targets/training_target.tscn")


func test_chain_lightning_spends_mana_and_damages_three_unique_targets() -> void:
	var world: Node3D = Node3D.new()
	add_child_autofree(world)
	var player: MagePlayer = PLAYER_SCENE.instantiate() as MagePlayer
	world.add_child(player)
	var targets: Array[TrainingTarget] = []
	for position: Vector3 in [
		Vector3(0.0, 0.0, -4.0),
		Vector3(2.5, 0.0, -4.0),
		Vector3(5.0, 0.0, -4.0),
	]:
		var target: TrainingTarget = TARGET_SCENE.instantiate() as TrainingTarget
		target.position = position
		world.add_child(target)
		targets.append(target)

	var loadout: SpellLoadout = player.get_spell_loadout()
	var caster: SpellCaster = player.get_spell_caster()
	var mana: ManaComponent = player.get_mana_component()
	assert_true(loadout.select_slot(2))
	var mana_before: float = mana.current_mana
	assert_true(caster.cast_at(targets[0].global_position))
	assert_eq(mana.current_mana, mana_before - caster.spell_data.mana_cost)
	for target: TrainingTarget in targets:
		assert_eq(target.get_health_component().current_health, 42.0 - caster.spell_data.damage)


func test_chain_lightning_refunds_mana_when_no_target_exists() -> void:
	var world: Node3D = Node3D.new()
	add_child_autofree(world)
	var player: MagePlayer = PLAYER_SCENE.instantiate() as MagePlayer
	world.add_child(player)
	var loadout: SpellLoadout = player.get_spell_loadout()
	var caster: SpellCaster = player.get_spell_caster()
	var mana: ManaComponent = player.get_mana_component()
	assert_true(loadout.select_slot(2))
	var mana_before: float = mana.current_mana
	assert_false(caster.cast_at(Vector3(0.0, 0.0, -4.0)))
	assert_eq(mana.current_mana, mana_before)
