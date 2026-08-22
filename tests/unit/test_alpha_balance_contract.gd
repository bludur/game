extends GutTest

const WORLD_SCENE: PackedScene = preload("res://scenes/survival/world_session.tscn")
const RECIPE_CATALOG: RecipeCatalog = preload("res://resources/survival/recipe_catalog.tres")
const BUILDING_CATALOG: BuildingCatalog = preload("res://resources/survival/building_catalog.tres")


func test_first_night_has_five_to_seven_minutes_of_preparation() -> void:
	var session: WorldSession = WORLD_SCENE.instantiate() as WorldSession
	add_child_autofree(session)
	await get_tree().process_frame
	var seconds_until_night: float = (
		0.8 - session.world_clock.starting_time
	) * session.world_clock.day_duration_seconds
	assert_gte(seconds_until_night, 300.0)
	assert_lte(seconds_until_night, 420.0)


func test_starter_refuge_costs_are_small_and_ward_is_meaningful() -> void:
	var foundation: BuildingPieceData = BUILDING_CATALOG.get_piece(&"foundation")
	var hearth: BuildingPieceData = BUILDING_CATALOG.get_piece(&"witchfire_hearth")
	assert_eq(_ingredient_total(foundation.ingredients), 3)
	assert_eq(_ingredient_total(hearth.ingredients), 4)
	assert_gte(hearth.ward_radius, 7.0)


func test_boss_preparations_and_eclipse_tier_stay_inside_authored_cost_bands() -> void:
	for preparation_id: StringName in [
		&"brew_frostward_tonic", &"brew_antivenom", &"brew_courage_tonic",
		&"brew_deep_frostward",
	]:
		var preparation: RecipeData = RECIPE_CATALOG.get_recipe(preparation_id)
		assert_not_null(preparation)
		assert_lte(_ingredient_total(preparation.ingredients), 4)
	for equipment_id: StringName in [
		&"forge_moonspine_focus", &"weave_eclipse_raiment", &"bind_eclipse_talisman",
	]:
		var equipment_recipe: RecipeData = RECIPE_CATALOG.get_recipe(equipment_id)
		var total: int = _ingredient_total(equipment_recipe.ingredients)
		assert_gte(total, 4)
		assert_lte(total, 6)
	var portal_focus: RecipeData = RECIPE_CATALOG.get_recipe(&"great_portal_focus")
	assert_eq(portal_focus.knowledge_id, &"great_portal")
	assert_lte(_ingredient_total(portal_focus.ingredients), 9)


func _ingredient_total(ingredients: Array[ItemAmountData]) -> int:
	var total: int = 0
	for ingredient: ItemAmountData in ingredients:
		total += ingredient.quantity
	return total
