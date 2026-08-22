class_name RecipeCatalog
extends Resource

@export var recipes: Array[RecipeData] = []


func get_recipe(recipe_id: StringName) -> RecipeData:
	for recipe: RecipeData in recipes:
		if recipe != null and recipe.recipe_id == recipe_id:
			return recipe
	return null
