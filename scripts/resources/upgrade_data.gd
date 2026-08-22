class_name UpgradeData
extends Resource

enum EffectType {
	ARCANE_DAMAGE,
	MANA_REGENERATION,
	MAX_HEALTH,
	CHAIN_DAMAGE,
	MAX_MANA,
	DASH_COOLDOWN,
}

@export_group("Identity")
@export var upgrade_id: StringName
@export var display_name: String = "Upgrade"
@export_multiline var description: String
@export var accent_color: Color = Color(0.65, 0.35, 1.0, 1.0)

@export_group("Effect")
@export var effect_type: EffectType = EffectType.ARCANE_DAMAGE
@export_range(0.1, 1000.0, 0.5) var amount: float = 5.0


func is_valid_definition() -> bool:
	return not String(upgrade_id).is_empty() \
		and not display_name.is_empty() \
		and not description.is_empty() \
		and amount > 0.0
