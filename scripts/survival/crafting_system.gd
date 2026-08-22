class_name CraftingSystem
extends Node

signal crafting_succeeded(recipe: RecipeData)
signal crafting_failed(recipe_id: StringName, reason: StringName)

@export var catalog: RecipeCatalog

var _inventory: InventoryComponent
var _grimoire: GrimoireState


func bind(inventory: InventoryComponent, grimoire: GrimoireState) -> void:
	_inventory = inventory
	_grimoire = grimoire


func craft(recipe_id: StringName) -> bool:
	var recipe: RecipeData = catalog.get_recipe(recipe_id) if catalog != null else null
	if recipe == null or _inventory == null or _grimoire == null:
		crafting_failed.emit(recipe_id, &"missing_definition")
		return false
	if not _grimoire.is_recipe_unlocked(recipe_id):
		crafting_failed.emit(recipe_id, &"unknown_recipe")
		return false
	if not recipe.can_craft(_inventory):
		crafting_failed.emit(recipe_id, &"missing_ingredients")
		return false
	if not _inventory.can_accept(recipe.result_item, recipe.result_quantity):
		crafting_failed.emit(recipe_id, &"inventory_full")
		return false
	for ingredient: ItemAmountData in recipe.ingredients:
		_inventory.remove_by_id(ingredient.item.item_id, ingredient.quantity)
	var remaining: int = _inventory.add_item(recipe.result_item, recipe.result_quantity)
	if remaining > 0:
		for ingredient: ItemAmountData in recipe.ingredients:
			_inventory.add_item(ingredient.item, ingredient.quantity)
		_inventory.remove_by_id(recipe.result_item.item_id, recipe.result_quantity - remaining)
		crafting_failed.emit(recipe_id, &"inventory_full")
		return false
	crafting_succeeded.emit(recipe)
	return true
