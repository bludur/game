class_name RitualData
extends Resource

@export var ritual_id: StringName = &""
@export var display_name: String = ""
@export var school: SpellModifierData.School = SpellModifierData.School.ARCANE
@export var ingredients: Array[ItemAmountData] = []
@export_range(0.0, 50.0, 0.5) var corruption_cost: float = 0.0
@export var result_flag: StringName = &""
@export_multiline var preview_text: String = ""


func can_perform(inventory: InventoryComponent) -> bool:
	for ingredient: ItemAmountData in ingredients:
		if ingredient == null or ingredient.item == null \
				or not inventory.has_item_id(ingredient.item.item_id, ingredient.quantity):
			return false
	return true
