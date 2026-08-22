class_name BossHazard
extends Area3D

signal activated()
signal damage_applied(hit_count: int)

var _damage: float = 0.0
var _source_faction: StringName = &"enemy"
var _cancelled: bool = false

@onready var _collision_shape: CollisionShape3D = get_node("CollisionShape3D") as CollisionShape3D
@onready var _visual: MeshInstance3D = get_node("TelegraphVisual") as MeshInstance3D
@onready var _activation_timer: Timer = get_node("ActivationTimer") as Timer
@onready var _lifetime_timer: Timer = get_node("LifetimeTimer") as Timer


func _ready() -> void:
	monitoring = false
	_activation_timer.timeout.connect(_apply_damage)
	_lifetime_timer.timeout.connect(queue_free)


func configure(attack: BossAttackData, origin: Vector3, direction: Vector3) -> void:
	_damage = attack.damage
	global_position = origin
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		direction = Vector3.FORWARD
	look_at(origin + direction.normalized(), Vector3.UP)
	match attack.attack_type:
		BossAttackData.AttackType.DIRECTED_STRIKE:
			_configure_line(attack.width, attack.length)
		BossAttackData.AttackType.EXPANDING_WAVE:
			_configure_wave(attack.radius)
		_:
			push_error("BossHazard received a non-hazard attack.")
	_set_visual_color(Color(1.0, 0.12, 0.2, 0.3), 1.6)


func activate() -> void:
	if _cancelled:
		return
	monitoring = true
	_set_visual_color(Color(1.0, 0.34, 0.12, 0.72), 4.5)
	_activation_timer.start(0.06)
	_lifetime_timer.start(0.28)
	activated.emit()


func cancel() -> void:
	_cancelled = true
	monitoring = false
	_activation_timer.stop()
	_lifetime_timer.stop()
	queue_free()


func _configure_line(width: float, length: float) -> void:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(width, 1.0, length)
	_collision_shape.shape = shape
	_collision_shape.position = Vector3(0.0, 0.5, -length * 0.5)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(width, 0.05, length)
	_visual.mesh = mesh
	_visual.position = Vector3(0.0, 0.04, -length * 0.5)


func _configure_wave(radius: float) -> void:
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = radius
	_collision_shape.shape = shape
	_collision_shape.position = Vector3(0.0, 0.45, 0.0)
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.05
	mesh.radial_segments = 48
	_visual.mesh = mesh
	_visual.position = Vector3(0.0, 0.04, 0.0)


func _set_visual_color(color: Color, energy: float) -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	_visual.material_override = material


func _apply_damage() -> void:
	if _cancelled:
		return
	var hit_ids: Array[int] = []
	for area: Area3D in get_overlapping_areas():
		if area is not HurtboxComponent:
			continue
		var hurtbox: HurtboxComponent = area as HurtboxComponent
		var target_id: int = hurtbox.get_instance_id()
		if hit_ids.has(target_id) or hurtbox.belongs_to(_source_faction):
			continue
		if hurtbox.receive_hit(_damage):
			hit_ids.append(target_id)
	monitoring = false
	damage_applied.emit(hit_ids.size())
