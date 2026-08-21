extends GutTest

const ARCANE_BOLT: SpellData = preload("res://resources/spells/arcane_bolt.tres")

var _spell: SpellData


func before_each() -> void:
	_spell = ARCANE_BOLT


func test_arcane_bolt_loads() -> void:
	assert_not_null(_spell)


func test_arcane_bolt_has_valid_definition() -> void:
	assert_true(_spell.is_valid_definition())


func test_arcane_bolt_uses_expected_identity() -> void:
	assert_eq(_spell.spell_id, &"arcane_bolt")
	assert_eq(_spell.display_name, "Arcane Bolt")


func test_arcane_bolt_combat_values_are_positive() -> void:
	assert_gt(_spell.damage, 0.0)
	assert_gt(_spell.projectile_speed, 0.0)
	assert_gt(_spell.range_meters, 0.0)


func test_arcane_bolt_has_a_projectile_scene() -> void:
	assert_not_null(_spell.projectile_scene)
