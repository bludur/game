extends GutTest

const DIRECTED: BossAttackData = preload("res://resources/boss_attacks/directed_strike.tres")
const WAVE: BossAttackData = preload("res://resources/boss_attacks/expanding_wave.tres")
const SUMMON: BossAttackData = preload("res://resources/boss_attacks/summon_guard.tres")


func test_boss_attack_definitions_are_valid_unique_and_cover_three_roles() -> void:
	var attacks: Array[BossAttackData] = [DIRECTED, WAVE, SUMMON]
	var ids: Array[StringName] = []
	var types: Array[int] = []
	for attack: BossAttackData in attacks:
		assert_true(attack.is_valid_definition())
		assert_false(ids.has(attack.attack_id))
		ids.append(attack.attack_id)
		types.append(attack.attack_type)
	assert_eq(types.size(), BossAttackData.AttackType.size())
