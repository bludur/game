class_name LootEntryData
extends Resource

@export var item: ItemData
@export_range(1, 99, 1) var minimum_quantity: int = 1
@export_range(1, 99, 1) var maximum_quantity: int = 1
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0


func roll_quantity(random: RandomNumberGenerator) -> int:
	return random.randi_range(minimum_quantity, maxi(minimum_quantity, maximum_quantity))
