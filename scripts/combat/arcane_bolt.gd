class_name ArcaneBolt
extends Area3D

signal hit_confirmed(target: HurtboxComponent)

@export var impact_scene: PackedScene

var _direction: Vector3 = Vector3.FORWARD
var _speed: float = 18.0
var _damage: float = 10.0
var _remaining_distance: float = 20.0
var _caster_body: Node3D
var _source_faction: StringName = &"neutral"
var _configured: bool = false
var _finished: bool = false


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	reset_physics_interpolation()


func configure(
	direction: Vector3,
	spell: SpellData,
	caster: Node3D,
	source_faction: StringName = &"neutral"
) -> void:
	_direction = direction.normalized()
	_speed = spell.projectile_speed
	_damage = spell.damage
	_remaining_distance = spell.range_meters
	_caster_body = caster
	_source_faction = source_faction
	_configured = true
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
	_spawn_impact()
	queue_free()


func _spawn_impact() -> void:
	if impact_scene == null or get_tree().current_scene == null:
		return
	var impact_node: Node = impact_scene.instantiate()
	if impact_node is not Node3D:
		impact_node.queue_free()
		return
	var impact: Node3D = impact_node as Node3D
	get_tree().current_scene.add_child(impact)
	impact.global_position = global_position
