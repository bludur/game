class_name ItemCatalog
extends Resource

@export var items: Array[ItemData] = []


func get_item(item_id: StringName) -> ItemData:
	for item: ItemData in items:
		if item != null and item.item_id == item_id:
			return item
	return null


func is_valid_catalog() -> bool:
	var known_ids: Dictionary[StringName, bool] = {}
	for item: ItemData in items:
		if item == null or not item.is_valid_definition() or known_ids.has(item.item_id):
			return false
		known_ids[item.item_id] = true
	return not items.is_empty()
