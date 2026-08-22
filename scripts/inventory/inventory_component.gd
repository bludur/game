class_name InventoryComponent
extends Node

signal inventory_changed()
signal item_added(item: ItemData, quantity: int)
signal item_removed(item: ItemData, quantity: int)
signal drop_requested(item: ItemData, quantity: int)

@export_range(1, 60, 1) var capacity: int = 24

var slots: Array[InventorySlot] = []


func _ready() -> void:
	if slots.is_empty():
		initialize_slots()


func initialize_slots() -> void:
	slots.clear()
	for _index: int in capacity:
		slots.append(InventorySlot.new())
	inventory_changed.emit()


func add_item(item: ItemData, quantity: int = 1) -> int:
	if item == null or quantity <= 0:
		return maxi(quantity, 0)
	var remaining: int = quantity
	for slot: InventorySlot in slots:
		if remaining <= 0:
			break
		if slot.can_stack(item):
			remaining = slot.add_to_stack(remaining)
	for slot: InventorySlot in slots:
		if remaining <= 0:
			break
		if slot.is_empty():
			slot.item = item
			remaining = slot.add_to_stack(remaining)
	var added: int = quantity - remaining
	if added > 0:
		item_added.emit(item, added)
		inventory_changed.emit()
	return remaining


func remove_item(item: ItemData, quantity: int = 1) -> int:
	if item == null or quantity <= 0:
		return 0
	return remove_by_id(item.item_id, quantity)


func remove_by_id(item_id: StringName, quantity: int = 1) -> int:
	var remaining: int = maxi(quantity, 0)
	for slot: InventorySlot in slots:
		if remaining <= 0:
			break
		if not slot.is_empty() and slot.item.item_id == item_id:
			remaining -= slot.remove_from_stack(remaining)
	var removed: int = quantity - remaining
	if removed > 0:
		var definition: ItemData = find_definition(item_id)
		item_removed.emit(definition, removed)
		inventory_changed.emit()
	return removed


func remove_from_slot(slot_index: int, quantity: int = 1) -> int:
	if not _is_valid_index(slot_index) or quantity <= 0:
		return 0
	var slot: InventorySlot = slots[slot_index]
	if slot.is_empty():
		return 0
	var removed_item: ItemData = slot.item
	var removed: int = slot.remove_from_stack(quantity)
	if removed > 0:
		item_removed.emit(removed_item, removed)
		inventory_changed.emit()
	return removed


func has_item_id(item_id: StringName, quantity: int = 1) -> bool:
	return get_item_count(item_id) >= quantity


func get_item_count(item_id: StringName) -> int:
	var total: int = 0
	for slot: InventorySlot in slots:
		if not slot.is_empty() and slot.item.item_id == item_id:
			total += slot.quantity
	return total


func can_accept(item: ItemData, quantity: int = 1) -> bool:
	if item == null or quantity <= 0:
		return false
	var available_space: int = 0
	for slot: InventorySlot in slots:
		if slot.is_empty():
			available_space += item.max_stack_size
		elif slot.item == item:
			available_space += item.max_stack_size - slot.quantity
		if available_space >= quantity:
			return true
	return false


func find_definition(item_id: StringName) -> ItemData:
	for slot: InventorySlot in slots:
		if not slot.is_empty() and slot.item.item_id == item_id:
			return slot.item
	return null


func swap_slots(first_index: int, second_index: int) -> bool:
	if not _is_valid_index(first_index) or not _is_valid_index(second_index):
		return false
	if first_index == second_index:
		return true
	var temporary: InventorySlot = slots[first_index]
	slots[first_index] = slots[second_index]
	slots[second_index] = temporary
	inventory_changed.emit()
	return true


func split_stack(source_index: int, target_index: int, amount: int = -1) -> bool:
	if not _is_valid_index(source_index) or not _is_valid_index(target_index):
		return false
	var source: InventorySlot = slots[source_index]
	var target: InventorySlot = slots[target_index]
	if source.is_empty() or not target.is_empty() or source_index == target_index:
		return false
	var split_amount: int = amount if amount > 0 else source.quantity / 2
	split_amount = mini(split_amount, source.quantity - 1)
	if split_amount <= 0:
		return false
	target.item = source.item
	target.quantity = split_amount
	source.quantity -= split_amount
	inventory_changed.emit()
	return true


func request_drop(slot_index: int, quantity: int = 1) -> bool:
	if not _is_valid_index(slot_index):
		return false
	var slot: InventorySlot = slots[slot_index]
	if slot.is_empty():
		return false
	var dropped_item: ItemData = slot.item
	var dropped_quantity: int = slot.remove_from_stack(quantity)
	if dropped_quantity <= 0:
		return false
	drop_requested.emit(dropped_item, dropped_quantity)
	inventory_changed.emit()
	return true


func extract_death_echo() -> Array[Dictionary]:
	var echo_items: Array[Dictionary] = []
	for slot: InventorySlot in slots:
		if slot.is_empty() or slot.item.item_type == ItemData.ItemType.KEY_ITEM:
			continue
		var lost_quantity: int = ceili(float(slot.quantity) * 0.5)
		echo_items.append({
			"item_id": String(slot.item.item_id),
			"quantity": lost_quantity,
		})
		slot.remove_from_stack(lost_quantity)
	if not echo_items.is_empty():
		inventory_changed.emit()
	return echo_items


func serialize() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for slot: InventorySlot in slots:
		if slot.is_empty():
			data.append({})
		else:
			data.append({"item_id": String(slot.item.item_id), "quantity": slot.quantity})
	return data


func deserialize(data: Array, catalog: ItemCatalog) -> void:
	initialize_slots()
	if catalog == null:
		push_error("InventoryComponent.deserialize: item catalog is missing.")
		return
	for index: int in mini(data.size(), slots.size()):
		var raw_entry: Variant = data[index]
		if raw_entry is not Dictionary:
			continue
		var entry: Dictionary = raw_entry as Dictionary
		var item_id: StringName = StringName(String(entry.get("item_id", "")))
		var definition: ItemData = catalog.get_item(item_id)
		if definition == null:
			continue
		slots[index].item = definition
		slots[index].quantity = clampi(int(entry.get("quantity", 0)), 0, definition.max_stack_size)
		if slots[index].quantity == 0:
			slots[index].clear()
	inventory_changed.emit()


func _is_valid_index(index: int) -> bool:
	return index >= 0 and index < slots.size()
