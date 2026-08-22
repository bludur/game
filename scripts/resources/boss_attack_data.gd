class_name BossAttackData
extends Resource

enum AttackType {
	DIRECTED_STRIKE,
	EXPANDING_WAVE,
	SUMMON,
}

@export_group("Identity")
@export var attack_id: StringName
@export var display_name: String = "Boss Attack"
@export var attack_type: AttackType = AttackType.DIRECTED_STRIKE

@export_group("Timing and Combat")
@export_range(0.2, 5.0, 0.05) var telegraph_duration: float = 1.0
@export_range(0.0, 200.0, 1.0) var damage: float = 18.0
@export_range(0.5, 20.0, 0.25) var radius: float = 4.0
@export_range(1.0, 30.0, 0.5) var length: float = 10.0
@export_range(0.5, 10.0, 0.25) var width: float = 2.0


func is_valid_definition() -> bool:
	return not String(attack_id).is_empty() \
		and not display_name.is_empty() \
		and telegraph_duration > 0.0 \
		and (attack_type == AttackType.SUMMON or damage > 0.0) \
		and radius > 0.0 \
		and length > 0.0 \
		and width > 0.0
