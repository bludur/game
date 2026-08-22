extends GutTest

const STATUS_SCENE: PackedScene = preload("res://scenes/components/status_effect_component.tscn")
const HEALTH_SCENE: PackedScene = preload("res://scenes/components/health_component.tscn")
const MANA_SCENE: PackedScene = preload("res://scenes/components/mana_component.tscn")
const STAMINA_SCENE: PackedScene = preload("res://scenes/components/stamina_component.tscn")
const CATALOG: StatusEffectCatalog = preload("res://resources/status_effects/status_effect_catalog.tres")

var _status: StatusEffectComponent
var _health: HealthComponent
var _mana: ManaComponent
var _stamina: StaminaComponent


func before_each() -> void:
	_status = STATUS_SCENE.instantiate() as StatusEffectComponent
	_health = HEALTH_SCENE.instantiate() as HealthComponent
	_mana = MANA_SCENE.instantiate() as ManaComponent
	_stamina = STAMINA_SCENE.instantiate() as StaminaComponent
	add_child_autofree(_health)
	add_child_autofree(_mana)
	add_child_autofree(_stamina)
	add_child_autofree(_status)
	_status.set_physics_process(false)
	_mana.set_process(false)
	_stamina.set_physics_process(false)
	_status.bind(_health, _mana, _stamina)


func after_each() -> void:
	get_tree().paused = false


func test_three_preparation_slots_coexist_and_same_slot_replaces() -> void:
	assert_true(_status.apply_effect(CATALOG.get_effect(&"ember_stew")))
	assert_true(_status.apply_effect(CATALOG.get_effect(&"clear_root")))
	assert_true(_status.apply_effect(CATALOG.get_effect(&"storm_binding")))
	assert_eq(_status.active_effects.size(), 3)
	assert_almost_eq(_health.max_health, 130.0, 0.001)
	assert_almost_eq(_mana.max_mana, 130.0, 0.001)
	assert_true(_status.apply_effect(CATALOG.get_effect(&"moonbread")))
	assert_eq(_status.active_effects.size(), 3)
	assert_null(_status.get_active_effect(&"ember_stew"))
	assert_not_null(_status.get_active_effect(&"moonbread"))
	assert_almost_eq(_health.max_health, 100.0, 0.001)
	assert_almost_eq(_stamina.max_stamina, 130.0, 0.001)


func test_refresh_never_duplicates_and_serialization_preserves_remaining_time() -> void:
	var rested: StatusEffectData = CATALOG.get_effect(&"rested")
	assert_true(_status.apply_effect(rested))
	_status.advance(37.25)
	assert_true(_status.apply_effect(rested))
	assert_eq(_status.active_effects.size(), 1)
	assert_almost_eq(_status.get_active_effect(&"rested").remaining_seconds, 900.0, 0.001)
	_status.advance(12.5)
	var snapshot: Array[Dictionary] = _status.serialize_state()
	_status.apply_state([])
	assert_true(_status.active_effects.is_empty())
	_status.apply_state(snapshot)
	assert_almost_eq(_status.get_active_effect(&"rested").remaining_seconds, 887.5, 0.001)


func test_preparation_improves_survival_without_becoming_mandatory() -> void:
	assert_true(_health.take_damage(40.0))
	var unprepared_health: float = _health.current_health
	_status.advance(10.0)
	assert_almost_eq(_health.current_health, unprepared_health, 0.001)
	_status.apply_effect(CATALOG.get_effect(&"ember_stew"))
	_status.apply_effect(CATALOG.get_effect(&"rested"))
	_status.advance(10.0)
	assert_gt(_health.current_health, unprepared_health)
	assert_gt(_status.get_resistance(StatusEffectData.ResistanceType.CORRUPTION), 0.09)


func test_catalog_and_authored_preparations_cover_required_resistances() -> void:
	assert_true(CATALOG.is_valid_catalog())
	assert_eq(CATALOG.effects.size(), 10)
	for resistance_type: StatusEffectData.ResistanceType in [
		StatusEffectData.ResistanceType.FROST,
		StatusEffectData.ResistanceType.CORRUPTION,
		StatusEffectData.ResistanceType.POISON,
		StatusEffectData.ResistanceType.FEAR,
	]:
		var covered: bool = false
		for definition: StatusEffectData in CATALOG.effects:
			covered = covered or definition.get_resistance(resistance_type) > 0.0
		assert_true(covered)


func test_scene_pause_does_not_consume_effect_duration() -> void:
	_status.apply_effect(CATALOG.get_effect(&"rested"))
	_status.set_physics_process(true)
	var before_pause: float = _status.get_active_effect(&"rested").remaining_seconds
	get_tree().paused = true
	await get_tree().create_timer(0.08, true, false, true).timeout
	get_tree().paused = false
	assert_almost_eq(
		_status.get_active_effect(&"rested").remaining_seconds,
		before_pause,
		0.001
	)


func test_expiring_effect_only_regenerates_for_its_remaining_duration() -> void:
	var brief_effect: StatusEffectData = StatusEffectData.new()
	brief_effect.effect_id = &"brief_regeneration"
	brief_effect.display_name = "Brief regeneration"
	brief_effect.source_id = &"test"
	brief_effect.duration_seconds = 1.0
	brief_effect.health_regeneration = 4.0
	_health.take_damage(20.0)
	_status.apply_effect(brief_effect)
	_status.advance(2.0)
	assert_almost_eq(_health.current_health, 84.0, 0.001)
	assert_true(_status.active_effects.is_empty())
