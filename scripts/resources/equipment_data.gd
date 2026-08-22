class_name EquipmentData
extends Resource

enum Slot {
	FOCUS,
	ROBE,
	TALISMAN,
}

enum Tier {
	WORN,
	BOUND,
	RELIC,
	ECLIPSE,
}

enum Condition {
	ALWAYS,
	HIGH_MANA,
	LOW_HEALTH,
	HIGH_CORRUPTION,
	HIGH_STAMINA,
}

@export_group("Identity")
@export var equipment_id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var slot: Slot = Slot.FOCUS
@export var tier: Tier = Tier.WORN
@export var accent_color: Color = Color(0.68, 0.42, 1.0, 1.0)

@export_group("Spell Profile")
@export_range(0.5, 1.5, 0.05) var cooldown_multiplier: float = 1.0
@export_range(0.5, 1.75, 0.05) var mana_cost_multiplier: float = 1.0
@export_range(0.5, 2.0, 0.05) var damage_multiplier: float = 1.0
@export_range(0.5, 2.0, 0.05) var projectile_speed_multiplier: float = 1.0
@export_range(0.5, 2.0, 0.05) var area_radius_multiplier: float = 1.0
@export_range(0.5, 2.0, 0.05) var effect_duration_multiplier: float = 1.0
@export_range(0.5, 2.0, 0.05) var chain_jump_multiplier: float = 1.0
@export var school_affinity: SpellModifierData.School = SpellModifierData.School.ARCANE
@export_range(1.0, 2.0, 0.05) var affinity_damage_multiplier: float = 1.0
@export_range(0.0, 20.0, 0.5) var corruption_per_cast: float = 0.0

@export_group("Defense")
@export_range(0.5, 1.5, 0.05) var incoming_damage_multiplier: float = 1.0

@export_group("Conditional Effect")
@export var condition: Condition = Condition.ALWAYS
@export_range(0.0, 1.0, 0.05) var condition_threshold: float = 0.0
@export_range(0.5, 2.0, 0.05) var conditional_damage_multiplier: float = 1.0
@export_range(0.5, 1.5, 0.05) var conditional_cooldown_multiplier: float = 1.0
@export_range(0.5, 1.5, 0.05) var conditional_incoming_damage_multiplier: float = 1.0

@export_group("Presentation")
@export_range(0, 3, 1) var visual_variant: int = 0


func is_valid_definition() -> bool:
	return not equipment_id.is_empty() and not display_name.is_empty() \
		and cooldown_multiplier > 0.0 and mana_cost_multiplier > 0.0 \
		and damage_multiplier > 0.0 and projectile_speed_multiplier > 0.0 \
		and area_radius_multiplier > 0.0 and effect_duration_multiplier > 0.0 \
		and chain_jump_multiplier > 0.0 and incoming_damage_multiplier > 0.0


func matches_item(item: ItemData) -> bool:
	return item != null and item.item_id == equipment_id and item.equipment == self
