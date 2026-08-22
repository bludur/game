extends GutTest

const DAMAGE_UPGRADE: UpgradeData = preload("res://resources/upgrades/arcane_damage.tres")
const MANA_UPGRADE: UpgradeData = preload("res://resources/upgrades/mana_regeneration.tres")
const HEALTH_UPGRADE: UpgradeData = preload("res://resources/upgrades/maximum_health.tres")
const CHAIN_UPGRADE: UpgradeData = preload("res://resources/upgrades/chain_damage.tres")
const CAPACITY_UPGRADE: UpgradeData = preload("res://resources/upgrades/mana_capacity.tres")
const DASH_UPGRADE: UpgradeData = preload("res://resources/upgrades/rapid_dash.tres")


func test_all_upgrade_definitions_are_valid_and_unique() -> void:
	var upgrades: Array[UpgradeData] = [
		DAMAGE_UPGRADE,
		MANA_UPGRADE,
		HEALTH_UPGRADE,
		CHAIN_UPGRADE,
		CAPACITY_UPGRADE,
		DASH_UPGRADE,
	]
	var ids: Array[StringName] = []
	for upgrade: UpgradeData in upgrades:
		assert_true(upgrade.is_valid_definition())
		assert_false(ids.has(upgrade.upgrade_id))
		ids.append(upgrade.upgrade_id)
	assert_eq(upgrades.size(), UpgradeData.EffectType.size())
