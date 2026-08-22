class_name LootTableData
extends Resource

@export var entries: Array[LootEntryData] = []


func roll(random: RandomNumberGenerator) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	var total_weight: float = 0.0
	for entry: LootEntryData in entries:
		if entry != null and entry.item != null:
			total_weight += maxf(0.0, entry.weight)
	if total_weight <= 0.0:
		return result
	var cursor: float = random.randf_range(0.0, total_weight)
	for entry: LootEntryData in entries:
		if entry == null or entry.item == null:
			continue
		cursor -= maxf(0.0, entry.weight)
		if cursor <= 0.0:
			result[entry.item.item_id] = entry.roll_quantity(random)
			return result
	return result
