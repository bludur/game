extends GutTest

const MANA_SCENE: PackedScene = preload("res://scenes/components/mana_component.tscn")

var _mana: ManaComponent


func before_each() -> void:
	_mana = MANA_SCENE.instantiate() as ManaComponent
	_mana.max_mana = 100.0
	_mana.regeneration_per_second = 0.0
	add_child_autofree(_mana)


func test_starts_full() -> void:
	assert_eq(_mana.current_mana, 100.0)


func test_spending_available_mana_succeeds() -> void:
	assert_true(_mana.try_spend(8.0))
	assert_eq(_mana.current_mana, 92.0)


func test_spending_more_than_available_fails_without_mutation() -> void:
	_mana.try_spend(95.0)
	watch_signals(_mana)
	assert_false(_mana.try_spend(8.0))
	assert_eq(_mana.current_mana, 5.0)
	assert_signal_emitted(_mana, &"spend_failed")


func test_restore_clamps_to_maximum() -> void:
	_mana.try_spend(25.0)
	assert_true(_mana.restore(100.0))
	assert_eq(_mana.current_mana, 100.0)
