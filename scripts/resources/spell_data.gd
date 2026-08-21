class_name SpellData
extends Resource

enum TargetingType {
	PROJECTILE,
	AREA,
	SELF,
}

@export_group("Identity")
@export var spell_id: StringName
@export var display_name: String = "New Spell"
@export_multiline var description: String
@export var targeting_type: TargetingType = TargetingType.PROJECTILE

@export_group("Costs")
@export_range(0.0, 1000.0, 0.5) var mana_cost: float = 10.0
@export_range(0.0, 60.0, 0.05) var cooldown_seconds: float = 0.5

@export_group("Combat")
@export_range(0.0, 10000.0, 0.5) var damage: float = 12.0
@export_range(0.0, 100.0, 0.5) var projectile_speed: float = 16.0
@export_range(0.0, 100.0, 0.5) var range_meters: float = 18.0

@export_group("Presentation")
@export var cast_color: Color = Color(0.55, 0.3, 1.0, 1.0)
@export var projectile_scene: PackedScene


func is_valid_definition() -> bool:
	return not String(spell_id).is_empty() \
		and not display_name.is_empty() \
		and mana_cost >= 0.0 \
		and cooldown_seconds >= 0.0 \
		and damage >= 0.0 \
		and projectile_speed > 0.0 \
		and range_meters > 0.0 \
		and projectile_scene != null
