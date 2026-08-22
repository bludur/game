extends GutTest


func test_stacking_splitting_dropping_and_serialization_are_lossless() -> void:
	var gravewood: ItemData = _make_item(&"gravewood", 30)
	var inventory: InventoryComponent = InventoryComponent.new()
	inventory.capacity = 3
	add_child_autofree(inventory)
	assert_eq(inventory.add_item(gravewood, 47), 0)
	assert_eq(inventory.slots[0].quantity, 30)
	assert_eq(inventory.slots[1].quantity, 17)
	assert_true(inventory.split_stack(0, 2, 9))
	assert_eq(inventory.slots[0].quantity, 21)
	assert_eq(inventory.slots[2].quantity, 9)
	var dropped: Array[int] = []
	inventory.drop_requested.connect(
		func(_item: ItemData, quantity: int) -> void: dropped.append(quantity)
	)
	assert_true(inventory.request_drop(2, 4))
	assert_eq(dropped, [4])
	assert_eq(inventory.get_item_count(&"gravewood"), 43)

	var catalog: ItemCatalog = ItemCatalog.new()
	catalog.items.append(gravewood)
	var restored: InventoryComponent = InventoryComponent.new()
	restored.capacity = 3
	add_child_autofree(restored)
	restored.deserialize(inventory.serialize(), catalog)
	assert_eq(restored.get_item_count(&"gravewood"), 43)
	assert_eq(restored.serialize(), inventory.serialize())


func test_capacity_returns_remainder_and_key_items_survive_death_echo() -> void:
	var material: ItemData = _make_item(&"moonstone", 5)
	var key_item: ItemData = _make_item(&"crypt_key", 1)
	key_item.item_type = ItemData.ItemType.KEY_ITEM
	var inventory: InventoryComponent = InventoryComponent.new()
	inventory.capacity = 2
	add_child_autofree(inventory)
	assert_eq(inventory.add_item(material, 8), 0)
	assert_eq(inventory.add_item(key_item, 1), 1)
	assert_eq(inventory.add_item(material, 5), 3)
	inventory.remove_by_id(&"moonstone", 5)
	assert_eq(inventory.add_item(key_item, 1), 0)
	var echo: Array[Dictionary] = inventory.extract_death_echo()
	assert_eq(echo.size(), 1)
	assert_eq(inventory.get_item_count(&"crypt_key"), 1)
	assert_eq(inventory.get_item_count(&"moonstone"), 2)


func _make_item(item_id: StringName, stack_size: int) -> ItemData:
	var item: ItemData = ItemData.new()
	item.item_id = item_id
	item.display_name = String(item_id)
	item.max_stack_size = stack_size
	return item
