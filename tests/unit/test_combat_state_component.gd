extends GutTest

const COMBAT_STATE_SCENE: PackedScene = preload(
	"res://scenes/components/combat_state_component.tscn"
)

var _combat_state: CombatStateComponent


func before_each() -> void:
	_combat_state = COMBAT_STATE_SCENE.instantiate() as CombatStateComponent
	add_child_autofree(_combat_state)
	_combat_state.set_physics_process(false)


func test_casting_advances_through_recovery_to_ready() -> void:
	assert_true(_combat_state.try_begin_cast())
	assert_eq(_combat_state.get_state_name(), &"casting")
	assert_false(_combat_state.try_begin_cast())
	_combat_state.advance(_combat_state.cast_duration)
	assert_eq(_combat_state.get_state_name(), &"recovery")
	_combat_state.advance(_combat_state.recovery_duration)
	assert_eq(_combat_state.get_state_name(), &"ready")


func test_dodge_can_cancel_recovery_but_stagger_blocks_dodge() -> void:
	assert_true(_combat_state.try_begin_cast())
	_combat_state.advance(_combat_state.cast_duration)
	assert_true(_combat_state.try_begin_dodge(0.25))
	assert_true(_combat_state.is_dodging())
	assert_false(_combat_state.begin_stagger())
	_combat_state.advance(0.25)
	assert_true(_combat_state.begin_stagger())
	assert_false(_combat_state.can_cast())
	assert_false(_combat_state.can_guard())
	assert_false(_combat_state.can_dodge())
	_combat_state.advance(_combat_state.stagger_duration)
	assert_true(_combat_state.can_cast())
