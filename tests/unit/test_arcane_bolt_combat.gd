extends GutTest

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player/player.tscn")
const TARGET_SCENE: PackedScene = preload("res://scenes/targets/training_target.tscn")


func test_arcane_bolt_spends_mana_and_damages_target() -> void:
	var world: Node3D = Node3D.new()
	add_child_autofree(world)

	var player: MagePlayer = PLAYER_SCENE.instantiate() as MagePlayer
	var target: TrainingTarget = TARGET_SCENE.instantiate() as TrainingTarget
	target.position = Vector3(0.0, 0.0, -4.0)
	world.add_child(player)
	world.add_child(target)

	var mana: ManaComponent = player.get_mana_component()
	var caster: SpellCaster = player.get_spell_caster()
	var target_health: HealthComponent = target.get_health_component()
	var mana_before: float = mana.current_mana
	var health_before: float = target_health.current_health

	caster.bind(
		player,
		player.get_node("CastOrigin") as Marker3D,
		mana,
		world,
		&"player",
		player.get_combat_state_component()
	)
	var target_hurtbox: HurtboxComponent = target.get_node("HurtboxComponent") as HurtboxComponent
	assert_true(caster.cast_at(target_hurtbox.global_position))
	assert_eq(mana.current_mana, mana_before - caster.spell_data.mana_cost)
	assert_eq(player.get_combat_state_component().get_state_name(), &"casting")

	for _frame: int in 30:
		await get_tree().physics_frame

	assert_eq(target_health.current_health, health_before - caster.spell_data.damage)
	assert_eq(player.get_health_component().current_health, player.get_health_component().max_health)
