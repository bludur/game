class_name StatusEffectData
extends Resource

enum StackPolicy {
	REFRESH,
	REPLACE,
	EXTEND,
	KEEP_STRONGEST,
}

enum PreparationSlot {
	NONE,
	FOOD,
	DRAUGHT,
	ENCHANTMENT,
}

enum ResistanceType {
	FROST,
	CORRUPTION,
	POISON,
	FEAR,
}

@export var effect_id: StringName
@export var display_name: String = ""
@export var source_id: StringName = &"unknown"
@export_range(1.0, 3600.0, 1.0) var duration_seconds: float = 300.0
@export var stack_policy: StackPolicy = StackPolicy.REFRESH
@export var preparation_slot: PreparationSlot = PreparationSlot.NONE
@export var accent_color: Color = Color(0.66, 0.42, 1.0, 1.0)

@export_group("Capacity")
@export_range(0.0, 500.0, 1.0) var maximum_health_bonus: float = 0.0
@export_range(0.0, 500.0, 1.0) var maximum_mana_bonus: float = 0.0
@export_range(0.0, 500.0, 1.0) var maximum_stamina_bonus: float = 0.0

@export_group("Regeneration Per Second")
@export_range(0.0, 50.0, 0.1) var health_regeneration: float = 0.0
@export_range(0.0, 50.0, 0.1) var mana_regeneration_bonus: float = 0.0
@export_range(0.0, 50.0, 0.1) var stamina_regeneration_bonus: float = 0.0

@export_group("Resistances")
@export_range(0.0, 0.85, 0.05) var frost_resistance: float = 0.0
@export_range(0.0, 0.85, 0.05) var corruption_resistance: float = 0.0
@export_range(0.0, 0.85, 0.05) var poison_resistance: float = 0.0
@export_range(0.0, 0.85, 0.05) var fear_resistance: float = 0.0


func is_valid_definition() -> bool:
	return not effect_id.is_empty() and not display_name.is_empty() \
		and not source_id.is_empty() and duration_seconds > 0.0


func get_resistance(resistance_type: ResistanceType) -> float:
	match resistance_type:
		ResistanceType.FROST:
			return frost_resistance
		ResistanceType.CORRUPTION:
			return corruption_resistance
		ResistanceType.POISON:
			return poison_resistance
		ResistanceType.FEAR:
			return fear_resistance
		_:
			return 0.0


func get_power_score() -> float:
	return maximum_health_bonus + maximum_mana_bonus + maximum_stamina_bonus \
		+ (health_regeneration + mana_regeneration_bonus + stamina_regeneration_bonus) * 5.0 \
		+ (frost_resistance + corruption_resistance + poison_resistance + fear_resistance) * 100.0
