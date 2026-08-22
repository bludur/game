class_name EnemyTelegraphComponent
extends Node3D

signal warning_started(definition: EnemyTelegraphData)
signal danger_started(definition: EnemyTelegraphData)
signal telegraph_finished()

enum Phase {
	IDLE,
	WARNING,
	DANGER,
}

@export var definition: EnemyTelegraphData

var current_phase: Phase = Phase.IDLE
var _time_remaining: float = 0.0
var _sfx_pool: SfxPool3D

@onready var _danger_area: Area3D = get_node("DangerArea") as Area3D
@onready var _shape: CollisionShape3D = get_node("DangerArea/CollisionShape3D") as CollisionShape3D
@onready var _disc: MeshInstance3D = get_node("DangerDisc") as MeshInstance3D
@onready var _light: OmniLight3D = get_node("WarningLight") as OmniLight3D


func _ready() -> void:
	top_level = true
	_disc.material_override = _disc.material_override.duplicate() as StandardMaterial3D
	_set_visible(false)
	set_physics_process(false)


func bind(sfx_pool: SfxPool3D) -> void:
	_sfx_pool = sfx_pool


func begin(override_definition: EnemyTelegraphData = null) -> bool:
	var next_definition: EnemyTelegraphData = definition if override_definition == null \
		else override_definition
	if current_phase != Phase.IDLE or next_definition == null \
			or not next_definition.is_valid_definition():
		return false
	definition = next_definition
	_configure_radius(definition.danger_radius)
	current_phase = Phase.WARNING
	_time_remaining = definition.warning_seconds
	_set_visible(true)
	_danger_area.monitoring = false
	_apply_color(definition.warning_color)
	if is_instance_valid(_sfx_pool):
		_sfx_pool.play_sfx(SyntheticAudio.create_enemy_warning(), -4.0)
	warning_started.emit(definition)
	set_physics_process(true)
	return true


func begin_at(world_position: Vector3, override_definition: EnemyTelegraphData = null) -> bool:
	global_position = world_position
	return begin(override_definition)


func _physics_process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if current_phase == Phase.IDLE or delta <= 0.0:
		return
	_time_remaining = maxf(0.0, _time_remaining - delta)
	if _time_remaining > 0.0:
		return
	if current_phase == Phase.WARNING:
		current_phase = Phase.DANGER
		_time_remaining = definition.danger_seconds
		_danger_area.set_deferred("monitoring", true)
		_apply_color(definition.danger_color)
		danger_started.emit(definition)
	else:
		finish()


func finish() -> void:
	if current_phase == Phase.IDLE:
		return
	current_phase = Phase.IDLE
	_time_remaining = 0.0
	_danger_area.set_deferred("monitoring", false)
	_set_visible(false)
	set_physics_process(false)
	telegraph_finished.emit()


func is_active() -> bool:
	return current_phase != Phase.IDLE


func get_phase_name() -> StringName:
	return StringName(Phase.keys()[current_phase].to_lower())


func get_time_remaining() -> float:
	return _time_remaining


func _configure_radius(radius: float) -> void:
	var cylinder_shape: CylinderShape3D = _shape.shape.duplicate() as CylinderShape3D
	cylinder_shape.radius = radius
	_shape.shape = cylinder_shape
	var cylinder_mesh: CylinderMesh = _disc.mesh.duplicate() as CylinderMesh
	cylinder_mesh.top_radius = radius
	cylinder_mesh.bottom_radius = radius
	_disc.mesh = cylinder_mesh
	_light.omni_range = maxf(2.0, radius * 2.2)


func _apply_color(color: Color) -> void:
	var material: StandardMaterial3D = _disc.material_override as StandardMaterial3D
	material.albedo_color = color
	material.emission = Color(color.r, color.g, color.b, 1.0)
	_light.light_color = Color(color.r, color.g, color.b, 1.0)


func _set_visible(visible: bool) -> void:
	_disc.visible = visible
	_light.visible = visible
