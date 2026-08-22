class_name RitualCatalog
extends Resource

@export var rituals: Array[RitualData] = []


func get_ritual(ritual_id: StringName) -> RitualData:
	for ritual: RitualData in rituals:
		if ritual != null and ritual.ritual_id == ritual_id:
			return ritual
	return null
