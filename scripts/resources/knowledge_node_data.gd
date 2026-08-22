class_name KnowledgeNodeData
extends Resource

enum RewardKind {
	SPELL,
	MODIFIER,
	RITUAL,
	EQUIPMENT_RECIPE,
}

@export_group("Identity")
@export var node_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var school: SpellModifierData.School = SpellModifierData.School.ARCANE
@export_range(1, 3, 1) var knowledge_level: int = 1

@export_group("Unlock")
@export var prerequisite_node_ids: Array[StringName] = []
@export var required_fragment_ids: Array[StringName] = []
@export var incompatible_node_ids: Array[StringName] = []

@export_group("Reward")
@export var reward_kind: RewardKind = RewardKind.MODIFIER
@export var reward_id: StringName = &""

@export_group("Active profile")
@export_range(0.5, 1.5, 0.01) var cooldown_multiplier: float = 1.0
@export_range(0.5, 1.5, 0.01) var mana_cost_multiplier: float = 1.0
@export_range(0.5, 2.0, 0.01) var damage_multiplier: float = 1.0
@export_range(0.5, 2.0, 0.01) var projectile_speed_multiplier: float = 1.0
@export_range(0.5, 2.0, 0.01) var area_radius_multiplier: float = 1.0
@export_range(0.5, 2.0, 0.01) var effect_duration_multiplier: float = 1.0
@export_range(0.5, 2.0, 0.01) var chain_jump_multiplier: float = 1.0


func is_valid_definition() -> bool:
	return not node_id.is_empty() and not display_name.is_empty() \
		and not description.is_empty() and knowledge_level >= 1 and knowledge_level <= 3 \
		and not reward_id.is_empty() and not required_fragment_ids.is_empty()


func effect_summary() -> String:
	var parts: PackedStringArray = PackedStringArray()
	_append_percent(parts, "перезарядка", cooldown_multiplier, true)
	_append_percent(parts, "мана", mana_cost_multiplier, true)
	_append_percent(parts, "урон", damage_multiplier)
	_append_percent(parts, "скорость снаряда", projectile_speed_multiplier)
	_append_percent(parts, "область", area_radius_multiplier)
	_append_percent(parts, "длительность", effect_duration_multiplier)
	_append_percent(parts, "дальность цепи", chain_jump_multiplier)
	return description if parts.is_empty() else "%s · %s" % [description, ", ".join(parts)]


func _append_percent(
	parts: PackedStringArray,
	label: String,
	multiplier: float,
	invert_benefit: bool = false
) -> void:
	if is_equal_approx(multiplier, 1.0):
		return
	var percent: int = roundi((multiplier - 1.0) * 100.0)
	if invert_benefit:
		percent = -percent
	parts.append("%s %+d%%" % [label, percent])
