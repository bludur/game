extends GutTest

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player/player.tscn")
const ITEM_CATALOG: ItemCatalog = preload("res://resources/survival/item_catalog.tres")
const RECIPE_CATALOG: RecipeCatalog = preload("res://resources/survival/recipe_catalog.tres")
const RITUAL_CATALOG: RitualCatalog = preload("res://resources/survival/ritual_catalog.tres")
const GRIMOIRE: GrimoireData = preload("res://resources/survival/grimoire.tres")


func test_crafting_is_atomic_and_respects_grimoire() -> void:
	var inventory: InventoryComponent = InventoryComponent.new()
	add_child_autofree(inventory)
	var grimoire: GrimoireState = GrimoireState.new()
	grimoire.definition = GRIMOIRE
	add_child_autofree(grimoire)
	var crafting: CraftingSystem = CraftingSystem.new()
	crafting.catalog = RECIPE_CATALOG
	add_child_autofree(crafting)
	crafting.bind(inventory, grimoire)
	inventory.add_item(ITEM_CATALOG.get_item(&"dusk_herb"), 2)
	inventory.add_item(ITEM_CATALOG.get_item(&"moonstone"), 1)
	assert_true(crafting.craft(&"brew_clear_root"))
	assert_eq(inventory.get_item_count(&"dusk_herb"), 0)
	assert_eq(inventory.get_item_count(&"moonstone"), 0)
	assert_eq(inventory.get_item_count(&"corruption_draught"), 1)
	var snapshot: Array[Dictionary] = inventory.serialize()
	assert_false(crafting.craft(&"brew_clear_root"))
	assert_eq(inventory.serialize(), snapshot)


func test_nine_authored_preparation_recipes_have_typed_effects() -> void:
	var preparation_recipe_ids: Array[StringName] = [
		&"brew_clear_root", &"cook_ember_stew", &"bake_moonbread",
		&"simmer_gravecap_broth", &"brew_frostward_tonic", &"brew_antivenom",
		&"brew_courage_tonic", &"inscribe_storm_binding", &"weave_witchfire_charm",
	]
	assert_eq(ITEM_CATALOG.items.size(), 46)
	assert_eq(RECIPE_CATALOG.recipes.size(), 35)
	for recipe_id: StringName in preparation_recipe_ids:
		var recipe: RecipeData = RECIPE_CATALOG.get_recipe(recipe_id)
		assert_not_null(recipe)
		assert_not_null(recipe.result_item.preparation_effect)
		assert_true(recipe.result_item.preparation_effect.is_valid_definition())


func test_ritual_consumes_once_sets_world_flag_and_applies_corruption() -> void:
	var player: MagePlayer = PLAYER_SCENE.instantiate() as MagePlayer
	add_child_autofree(player)
	var world_state: WorldState = WorldState.new()
	add_child_autofree(world_state)
	var circle: Node3D = Node3D.new()
	add_child_autofree(circle)
	var ritual_system: RitualSystem = RitualSystem.new()
	ritual_system.catalog = RITUAL_CATALOG
	add_child_autofree(ritual_system)
	var inventory: InventoryComponent = player.get_inventory_component()
	inventory.add_item(ITEM_CATALOG.get_item(&"soul_shard"), 4)
	ritual_system.bind(player, inventory, world_state, circle)
	assert_true(ritual_system.perform(&"forbidden_sight"))
	assert_true(world_state.has_ritual_flag(&"forbidden_sight_used"))
	assert_eq(inventory.get_item_count(&"soul_shard"), 2)
	assert_eq(player.get_corruption_component().current_corruption, 18.0)
	assert_false(ritual_system.perform(&"forbidden_sight"))
	assert_eq(inventory.get_item_count(&"soul_shard"), 2)
