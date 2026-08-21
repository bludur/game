extends GutTest

const HEALTH_SCENE: PackedScene = preload("res://scenes/components/health_component.tscn")

var _health: HealthComponent


func before_each() -> void:
	_health = HEALTH_SCENE.instantiate() as HealthComponent
	_health.max_health = 100.0
	add_child_autofree(_health)


func test_starts_full() -> void:
	assert_eq(_health.current_health, 100.0)
	assert_almost_eq(_health.get_health_ratio(), 1.0, 0.001)


func test_damage_reduces_health() -> void:
	assert_true(_health.take_damage(25.0))
	assert_eq(_health.current_health, 75.0)


func test_lethal_damage_clamps_to_zero_and_emits_died() -> void:
	watch_signals(_health)
	_health.take_damage(125.0)
	assert_eq(_health.current_health, 0.0)
	assert_signal_emitted(_health, &"died")


func test_reset_restores_full_health() -> void:
	_health.take_damage(80.0)
	_health.reset()
	assert_eq(_health.current_health, 100.0)
