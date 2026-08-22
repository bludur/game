class_name RecipeData
extends Resource

enum Station {
	CAULDRON,
	RUNE_TABLE,
	WEAVING_CIRCLE,
}

@export var recipe_id: StringName = &""
@export var display_name: String = ""
@export var station: Station = Station.CAULDRON
@export var ingredients: Array[ItemAmountData] = []
@export var result_item: ItemData
@export_range(1, 99, 1) var result_quantity: int = 1
@export_range(0.0, 60.0, 0.1) var craft_seconds: float = 0.0
@export var knowledge_id: StringName = &""


func can_craft(inventory: InventoryComponent) -> bool:
	if inventory == null or result_item == null:
		return false
	for ingredient: ItemAmountData in ingredients:
		if ingredient == null or ingredient.item == null \
				or not inventory.has_item_id(ingredient.item.item_id, ingredient.quantity):
			return false
	return true
