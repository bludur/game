class_name StatusEffectCatalog
extends Resource

@export var effects: Array[StatusEffectData] = []


func get_effect(effect_id: StringName) -> StatusEffectData:
	for effect: StatusEffectData in effects:
		if effect != null and effect.effect_id == effect_id:
			return effect
	return null


func is_valid_catalog() -> bool:
	var ids: Dictionary[StringName, bool] = {}
	for effect: StatusEffectData in effects:
		if effect == null or not effect.is_valid_definition() or ids.has(effect.effect_id):
			return false
		ids[effect.effect_id] = true
	return not effects.is_empty()
