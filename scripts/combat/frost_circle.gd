class_name FrostCircle
extends Area3D

signal effect_expired()

var _source_faction: StringName = &"neutral"
var _speed_multiplier: float = 0.5
var _affected_components: Dictionary[int, MovementModifierComponent] = {}

@onready var _collision_shape: CollisionShape3D = get_node("CollisionShape3D") as CollisionShape3D
@onready var _visuals: Node3D = get_node("Visuals") as Node3D
@onready var _particles: GPUParticles3D = get_node("Visuals/FrostParticles") as GPUParticles3D
@onready var _lifetime_timer: Timer = get_node("LifetimeTimer") as Timer


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	_lifetime_timer.timeout.connect(_on_lifetime_finished)
	_particles.restart()
	_particles.emitting = true
	reset_physics_interpolation()


func configure(spell: SpellData, source_faction: StringName) -> void:
	_source_faction = source_faction
	_speed_multiplier = spell.movement_speed_multiplier
	var sphere: SphereShape3D = _collision_shape.shape.duplicate() as SphereShape3D
	sphere.radius = spell.area_radius
	_collision_shape.shape = sphere
	_visuals.scale = Vector3.ONE * (spell.area_radius / 2.5)
	_lifetime_timer.start(spell.effect_duration)


func get_remaining_duration() -> float:
	return _lifetime_timer.time_left


func _exit_tree() -> void:
	_clear_modifiers()


func _on_area_entered(area: Area3D) -> void:
	if area is not HurtboxComponent:
		return
	var hurtbox: HurtboxComponent = area as HurtboxComponent
	if hurtbox.belongs_to(_source_faction):
		return
	var modifier: MovementModifierComponent = hurtbox.get_parent().get_node_or_null(
		"MovementModifierComponent"
	) as MovementModifierComponent
	if modifier == null:
		return
	var modifier_id: int = modifier.get_instance_id()
	_affected_components[modifier_id] = modifier
	modifier.add_modifier(get_instance_id(), _speed_multiplier)


func _on_area_exited(area: Area3D) -> void:
	if area is not HurtboxComponent:
		return
	var modifier: MovementModifierComponent = area.get_parent().get_node_or_null(
		"MovementModifierComponent"
	) as MovementModifierComponent
	if modifier == null:
		return
	modifier.remove_modifier(get_instance_id())
	_affected_components.erase(modifier.get_instance_id())


func _on_lifetime_finished() -> void:
	_clear_modifiers()
	effect_expired.emit()
	queue_free()


func _clear_modifiers() -> void:
	for modifier: MovementModifierComponent in _affected_components.values():
		if is_instance_valid(modifier):
			modifier.remove_modifier(get_instance_id())
	_affected_components.clear()
