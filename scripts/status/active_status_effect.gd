class_name ActiveStatusEffect
extends RefCounted

var definition: StatusEffectData
var remaining_seconds: float = 0.0


func _init(effect: StatusEffectData = null, remaining: float = 0.0) -> void:
	definition = effect
	remaining_seconds = remaining


func serialize() -> Dictionary:
	return {
		"effect_id": String(definition.effect_id) if definition != null else "",
		"remaining_seconds": remaining_seconds,
	}
