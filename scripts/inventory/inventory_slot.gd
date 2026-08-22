class_name InventorySlot
extends RefCounted

var item: ItemData
var quantity: int = 0


func is_empty() -> bool:
	return item == null or quantity <= 0


func can_stack(candidate: ItemData) -> bool:
	return not is_empty() and item == candidate and quantity < item.max_stack_size


func add_to_stack(amount: int) -> int:
	if item == null or amount <= 0:
		return maxi(0, amount)
	var accepted: int = mini(amount, item.max_stack_size - quantity)
	quantity += accepted
	return amount - accepted


func remove_from_stack(amount: int) -> int:
	var removed: int = mini(maxi(amount, 0), quantity)
	quantity -= removed
	if quantity <= 0:
		clear()
	return removed


func clear() -> void:
	item = null
	quantity = 0


func duplicate_slot() -> InventorySlot:
	var copy: InventorySlot = InventorySlot.new()
	copy.item = item
	copy.quantity = quantity
	return copy
