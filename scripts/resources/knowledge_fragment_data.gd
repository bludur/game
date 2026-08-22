class_name KnowledgeFragmentData
extends Resource

enum SourceKind {
	POINT_OF_INTEREST,
	BOSS,
	ELITE,
}

@export var fragment_id: StringName = &""
@export var display_name: String = ""
@export_multiline var source_hint: String = ""
@export var source_kind: SourceKind = SourceKind.POINT_OF_INTEREST
@export var source_id: StringName = &""
@export var school: SpellModifierData.School = SpellModifierData.School.ARCANE


func is_valid_definition() -> bool:
	return not fragment_id.is_empty() and not display_name.is_empty() \
		and not source_id.is_empty() and not source_hint.is_empty()
