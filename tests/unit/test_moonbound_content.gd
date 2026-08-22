extends GutTest

const REGION_SCENE: PackedScene = preload("res://scenes/regions/moonbound_expanse.tscn")
const ENCOUNTERS: EncounterTableData = preload("res://resources/survival/encounters/moonbound_encounters.tres")
const ITEM_CATALOG: ItemCatalog = preload("res://resources/survival/item_catalog.tres")
const RECIPE_CATALOG: RecipeCatalog = preload("res://resources/survival/recipe_catalog.tres")
const MOON_EATER_SCENE: PackedScene = preload("res://scenes/boss/moon_eater.tscn")


func test_authored_region_has_five_pois_twelve_nodes_and_four_resource_types() -> void:
	var region: MoonboundExpanse = REGION_SCENE.instantiate() as MoonboundExpanse
	add_child_autofree(region)
	assert_eq(region.region_data.region_id, &"moonbound_expanse")
	assert_eq(region.region_data.authored_size, Vector2(144, 144))
	assert_eq(region.get_pois().size(), 5)
	assert_eq(region.get_persistent_resources().size(), 12)
	var loot_ids: Dictionary[StringName, bool] = {}
	for resource_node: ResourceNode in region.get_persistent_resources():
		for entry: LootEntryData in resource_node.loot_table.entries:
			loot_ids[entry.item.item_id] = true
	assert_eq(loot_ids.size(), 4)


func test_new_tier_recipes_and_three_enemy_roles_are_valid() -> void:
	assert_true(ENCOUNTERS.is_valid_catalog())
	assert_eq(ENCOUNTERS.roles.size(), 3)
	for item_id: StringName in [&"moonspine_focus", &"eclipse_raiment", &"eclipse_talisman"]:
		var item: ItemData = ITEM_CATALOG.get_item(item_id)
		assert_not_null(item)
		assert_eq(item.equipment.tier, EquipmentData.Tier.ECLIPSE)
	for recipe_id: StringName in [
		&"smelt_lunar_alloy", &"weave_shadow_thread", &"forge_moonspine_focus",
		&"weave_eclipse_raiment", &"bind_eclipse_talisman", &"brew_deep_frostward",
	]:
		assert_not_null(RECIPE_CATALOG.get_recipe(recipe_id))


func test_moon_eater_has_two_phases_and_light_shadow_state() -> void:
	var boss: MoonEater = MOON_EATER_SCENE.instantiate() as MoonEater
	add_child_autofree(boss)
	var player: MagePlayer = preload("res://scenes/characters/player/player.tscn").instantiate() as MagePlayer
	add_child_autofree(player)
	assert_true(boss.start_encounter(player))
	assert_true(boss.moonlight_active)
	boss.get_health_component().take_damage(240.0)
	assert_eq(boss.current_phase, 2)
	assert_false(boss.moonlight_active)


func test_cold_is_reduced_by_frost_preparation_and_cleared_by_shelter() -> void:
	var player: MagePlayer = preload("res://scenes/characters/player/player.tscn").instantiate() as MagePlayer
	add_child_autofree(player)
	var cold: ColdExposureComponent = ColdExposureComponent.new()
	add_child_autofree(cold)
	cold.bind(player)
	cold.advance(5.0, true, false)
	var unprotected_gain: float = cold.current_exposure
	cold.current_exposure = 0.0
	assert_true(player.get_status_effect_component().apply_effect_by_id(&"frostward_tonic"))
	cold.advance(5.0, true, false)
	assert_lt(cold.current_exposure, unprotected_gain)
	cold.advance(5.0, true, true)
	assert_eq(cold.current_exposure, 0.0)
