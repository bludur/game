class_name CultistBolt
extends Area3D

signal hit_confirmed(target: HurtboxComponent)

@export_range(1.0, 40.0, 0.5) var default_speed: float = 11.0
@export_range(1.0, 100.0, 1.0) var default_damage: float = 7.0
@export_range(1.0, 40.0, 0.5) var default_range: float = 14.0

var _direction: Vector3 = Vector3.FORWARD
var _speed: float
var _damage: float
var _remaining_distance: float
var _caster_body: Node3D
var _source_faction: StringName = &"enemy"
var _configured: bool = false
var _finished: bool = false


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	reset_physics_interpolation()


func configure(
	direction: Vector3,
	damage: float = -1.0,
	speed: float = -1.0,
	range_meters: float = -1.0,
	caster: Node3D = null,
	source_faction: StringName = &"enemy"
) -> void:
	_direction = direction.normalized()
	_damage = damage if damage > 0.0 else default_damage
	_speed = speed if speed > 0.0 else default_speed
	_remaining_distance = range_meters if range_meters > 0.0 else default_range
	_caster_body = caster
	_source_faction = source_faction
	_configured = _direction.length_squared() > 0.001
	if _configured:
		look_at(global_position + _direction, Vector3.UP)
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if not _configured or _finished:
		return
	var travel_distance: float = minf(_speed * delta, _remaining_distance)
	global_position += _direction * travel_distance
	_remaining_distance -= travel_distance
	if _remaining_distance <= 0.0:
		_finish()


func _on_area_entered(area: Area3D) -> void:
	if _finished or area is not HurtboxComponent:
		return
	var hurtbox: HurtboxComponent = area as HurtboxComponent
	if hurtbox.belongs_to(_source_faction):
		return
	if hurtbox.receive_hit(_damage):
		hit_confirmed.emit(hurtbox)
		_finish()


func _on_body_entered(body: Node3D) -> void:
	if _finished or body == _caster_body:
		return
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	queue_free()
