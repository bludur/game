extends GutTest

const STAMINA_SCENE: PackedScene = preload("res://scenes/components/stamina_component.tscn")


func test_spending_uses_one_shared_pool_and_emits_exhaustion_once() -> void:
	var stamina: StaminaComponent = STAMINA_SCENE.instantiate() as StaminaComponent
	stamina.max_stamina = 40.0
	stamina.regeneration_per_second = 10.0
	add_child_autofree(stamina)
	stamina.set_physics_process(false)
	var exhaustion_count: Array[int] = [0]
	stamina.exhausted.connect(func() -> void: exhaustion_count[0] += 1)

	assert_true(stamina.try_spend(16.0))
	assert_almost_eq(stamina.current_stamina, 24.0, 0.001)
	assert_false(stamina.try_spend(25.0))
	assert_almost_eq(stamina.current_stamina, 24.0, 0.001)
	assert_true(stamina.spend_continuous(48.0, 0.5) == false)
	assert_almost_eq(stamina.current_stamina, 0.0, 0.001)
	assert_eq(exhaustion_count[0], 1)


func test_regeneration_waits_for_delay_then_recovers_deterministically() -> void:
	var stamina: StaminaComponent = STAMINA_SCENE.instantiate() as StaminaComponent
	stamina.max_stamina = 100.0
	stamina.regeneration_per_second = 20.0
	stamina.regeneration_delay_seconds = 0.75
	add_child_autofree(stamina)
	stamina.set_physics_process(false)

	assert_true(stamina.try_spend(30.0))
	stamina.advance(0.5)
	assert_almost_eq(stamina.current_stamina, 70.0, 0.001)
	stamina.advance(0.25)
	assert_almost_eq(stamina.current_stamina, 70.0, 0.001)
	stamina.advance(0.5)
	assert_almost_eq(stamina.current_stamina, 80.0, 0.001)


func test_reset_restores_full_stamina_and_clears_regeneration_delay() -> void:
	var stamina: StaminaComponent = STAMINA_SCENE.instantiate() as StaminaComponent
	add_child_autofree(stamina)
	stamina.set_physics_process(false)
	assert_true(stamina.try_spend(24.0))
	stamina.reset()
	assert_almost_eq(stamina.current_stamina, stamina.max_stamina, 0.001)
	assert_almost_eq(stamina.get_regeneration_delay_remaining(), 0.0, 0.001)
