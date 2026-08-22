class_name EnemyRoleData
extends Resource

enum ControllerKind {
	CHASER,
	CULTIST,
}

@export var role_id: StringName = &""
@export var display_name: String = ""
@export var controller_kind: ControllerKind = ControllerKind.CHASER
@export_range(1, 5, 1) var tier: int = 1
@export_range(0.1, 4.0, 0.05) var health_multiplier: float = 1.0
@export_range(0.1, 4.0, 0.05) var damage_multiplier: float = 1.0
@export_range(0.1, 3.0, 0.05) var speed_multiplier: float = 1.0
@export_range(0.25, 3.0, 0.05) var range_multiplier: float = 1.0
@export var silhouette_scale: Vector3 = Vector3.ONE
@export var signature_color: Color = Color(0.8, 0.2, 0.5, 1.0)
@export_range(0.5, 1.8, 0.05) var audio_pitch: float = 1.0
@export var flying: bool = false
@export var trophy_item_id: StringName = &"soul_shard"
@export var knowledge_id: StringName = &""


func is_valid_definition() -> bool:
	return not role_id.is_empty() and not display_name.is_empty() \
		and health_multiplier > 0.0 and damage_multiplier > 0.0 \
		and speed_multiplier > 0.0 and range_multiplier > 0.0 \
		and silhouette_scale.x > 0.0 and silhouette_scale.y > 0.0 \
		and silhouette_scale.z > 0.0 and not trophy_item_id.is_empty()
