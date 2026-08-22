extends GutTest

const ENCOUNTERS: EncounterTableData = preload(
	"res://resources/survival/encounters/ashen_grove_encounters.tres"
)
const CHASER_SCENE: PackedScene = preload("res://scenes/enemies/chaser_enemy.tscn")
const CULTIST_SCENE: PackedScene = preload("res://scenes/enemies/cultist_enemy.tscn")
const ITEM_CATALOG: ItemCatalog = preload("res://resources/survival/item_catalog.tres")
const RECIPE_CATALOG: RecipeCatalog = preload("res://resources/survival/recipe_catalog.tres")


func test_encounter_table_covers_six_roles_two_mutations_and_context_filters() -> void:
	assert_true(ENCOUNTERS.is_valid_catalog())
	assert_eq(ENCOUNTERS.roles.size(), 6)
	assert_eq(ENCOUNTERS.mutations.size(), 2)
	var controller_kinds: Dictionary[int, bool] = {}
	var silhouettes: Dictionary[String, bool] = {}
	var trophy_ids: Dictionary[StringName, bool] = {}
	for role: EnemyRoleData in ENCOUNTERS.roles:
		controller_kinds[role.controller_kind] = true
		silhouettes[str(role.silhouette_scale)] = true
		assert_false(role.trophy_item_id.is_empty())
		assert_not_null(ITEM_CATALOG.get_item(role.trophy_item_id))
		trophy_ids[role.trophy_item_id] = true
	assert_eq(controller_kinds.size(), 2)
	assert_gte(silhouettes.size(), 5)
	var day_ruins: Array[EncounterEntryData] = ENCOUNTERS.get_matching_entries(false, 10.0, 1, 2)
	assert_true(_contains_entry(day_ruins, &"wilds_day"))
	assert_true(_contains_entry(day_ruins, &"ruins_watch"))
	var tier_one_night: Array[EncounterEntryData] = ENCOUNTERS.get_matching_entries(true, 70.0, 1, 4)
	assert_true(_contains_entry(tier_one_night, &"crypt_watch"))
	assert_false(_contains_entry(tier_one_night, &"forbidden_hunt"))
	var tier_two_night: Array[EncounterEntryData] = ENCOUNTERS.get_matching_entries(true, 70.0, 2, 4)
	assert_true(_contains_entry(tier_two_night, &"forbidden_hunt"))
	var trophy_feeds_equipment: bool = false
	for recipe: RecipeData in RECIPE_CATALOG.recipes:
		if recipe.result_item == null or recipe.result_item.item_type != ItemData.ItemType.EQUIPMENT:
			continue
		for ingredient: ItemAmountData in recipe.ingredients:
			if ingredient != null and ingredient.item != null \
					and trophy_ids.has(ingredient.item.item_id):
				trophy_feeds_equipment = true
	assert_true(trophy_feeds_equipment)


func test_authored_lairs_have_finite_population_and_patrol_respawn_rules() -> void:
	assert_eq(ENCOUNTERS.lairs.size(), 4)
	var total_population: int = 0
	for lair: EnemyLairData in ENCOUNTERS.lairs:
		assert_true(lair.is_valid_definition())
		assert_gte(lair.patrol_points.size(), 3)
		assert_gte(lair.respawn_seconds, 120.0)
		total_population += lair.population_budget
	assert_eq(total_population, 8)


func test_guardian_and_both_elite_mutations_change_stats_and_visual_marks() -> void:
	var guardian: ChaserEnemy = CHASER_SCENE.instantiate() as ChaserEnemy
	add_child_autofree(guardian)
	var guardian_role: EnemyRoleData = ENCOUNTERS.get_role(&"root_guardian")
	guardian.configure_ecology(guardian_role, ENCOUNTERS.get_mutation(&"ashbound"))
	assert_eq(guardian.ecology_role_id, &"root_guardian")
	assert_eq(guardian.mutation_id, &"ashbound")
	assert_gt(guardian.get_health_component().max_health, 70.0)
	assert_not_null(guardian.get_node_or_null("Visuals/MutationMark"))
	var hunter: ChaserEnemy = CHASER_SCENE.instantiate() as ChaserEnemy
	add_child_autofree(hunter)
	hunter.configure_ecology(
		ENCOUNTERS.get_role(&"hollow_elite_hunter"),
		ENCOUNTERS.get_mutation(&"veilmarked")
	)
	assert_eq(hunter.mutation_id, &"veilmarked")
	assert_eq(hunter.knowledge_id, &"hollow_hunter_anatomy")
	assert_ne(
		(guardian.get_node("Visuals/Glow") as OmniLight3D).light_color,
		(hunter.get_node("Visuals/Glow") as OmniLight3D).light_color
	)


func test_flying_scout_uses_cultist_controller_with_distinct_profile() -> void:
	var scout: CultistEnemy = CULTIST_SCENE.instantiate() as CultistEnemy
	add_child_autofree(scout)
	var initial_height: float = scout.global_position.y
	scout.configure_ecology(ENCOUNTERS.get_role(&"ash_wisp_scout"))
	assert_eq(scout.ecology_role_id, &"ash_wisp_scout")
	assert_gt(scout.global_position.y, initial_height + 1.5)
	assert_lt(scout.get_health_component().max_health, 20.0)
	assert_gt(scout.move_speed, 3.5)


func test_raid_state_round_trip_prevents_duplicate_runtime_identity() -> void:
	var state: WorldState = WorldState.new()
	add_child_autofree(state)
	state.raid_state = {
		"active": true,
		"warning": false,
		"raid_type": int(ThreatDirector.RaidType.SOUL_SIEGE),
		"started_day": 3,
		"damage_applied": 48.0,
	}
	var restored: WorldState = WorldState.new()
	add_child_autofree(restored)
	restored.apply_state(state.serialize_state())
	assert_eq(restored.raid_state, state.raid_state)


func _contains_entry(entries: Array[EncounterEntryData], encounter_id: StringName) -> bool:
	for entry: EncounterEntryData in entries:
		if entry.encounter_id == encounter_id:
			return true
	return false
