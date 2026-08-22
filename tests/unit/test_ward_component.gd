extends GutTest

const STAMINA_SCENE: PackedScene = preload("res://scenes/components/stamina_component.tscn")
const MANA_SCENE: PackedScene = preload("res://scenes/components/mana_component.tscn")
const COMBAT_STATE_SCENE: PackedScene = preload(
	"res://scenes/components/combat_state_component.tscn"
)
const WARD_SCENE: PackedScene = preload("res://scenes/components/ward_component.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player/player.tscn")

var _stamina: StaminaComponent
var _mana: ManaComponent
var _combat_state: CombatStateComponent
var _ward: WardComponent


func before_each() -> void:
	_stamina = STAMINA_SCENE.instantiate() as StaminaComponent
	_mana = MANA_SCENE.instantiate() as ManaComponent
	_combat_state = COMBAT_STATE_SCENE.instantiate() as CombatStateComponent
	_ward = WARD_SCENE.instantiate() as WardComponent
	add_child_autofree(_stamina)
	add_child_autofree(_mana)
	add_child_autofree(_combat_state)
	add_child_autofree(_ward)
	_stamina.set_physics_process(false)
	_mana.set_process(false)
	_combat_state.set_physics_process(false)
	_ward.set_physics_process(false)
	_ward.bind(_stamina, _mana, _combat_state)


func test_ward_spends_both_resources_and_reduces_damage() -> void:
	_ward.advance(1.0, true)
	assert_true(_ward.is_active)
	assert_almost_eq(
		_stamina.current_stamina,
		_stamina.max_stamina - _ward.activation_stamina_cost - _ward.stamina_per_second,
		0.001
	)
	assert_almost_eq(_mana.current_mana, _mana.max_mana - _ward.mana_per_second, 0.001)
	var received_damage: float = _ward.filter_damage(40.0)
	assert_almost_eq(received_damage, 10.0, 0.001)


func test_ward_drops_during_dodge_and_breaks_without_block_stamina() -> void:
	_ward.advance(0.0, true)
	assert_true(_ward.is_active)
	assert_true(_combat_state.try_begin_dodge(0.25))
	_ward.advance(0.01, true)
	assert_false(_ward.is_active)
	_combat_state.advance(0.25)
	_stamina.try_spend(_stamina.current_stamina - 1.0)
	_ward.activation_stamina_cost = 0.0
	_ward.advance(0.0, true)
	assert_true(_ward.is_active)
	assert_almost_eq(_ward.filter_damage(20.0), 20.0, 0.001)
	assert_false(_ward.is_active)


func test_player_hurtbox_routes_damage_through_bound_ward() -> void:
	var world: Node3D = Node3D.new()
	add_child_autofree(world)
	var player: MagePlayer = PLAYER_SCENE.instantiate() as MagePlayer
	world.add_child(player)
	var ward: WardComponent = player.get_ward_component()
	ward.set_physics_process(false)
	ward.advance(0.0, true)
	var health: HealthComponent = player.get_health_component()
	var health_before: float = health.current_health
	assert_true(player.get_hurtbox_component().receive_hit(20.0))
	assert_almost_eq(health.current_health, health_before - 5.0, 0.001)
	assert_eq(player.get_combat_state_component().get_state_name(), &"staggered")
