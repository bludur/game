class_name TopDownCamera
extends Node3D

@export_group("Follow")
@export var target_group: StringName = &"player"
@export_range(1.0, 30.0, 0.5) var follow_speed: float = 9.0
@export_range(0.0, 4.0, 0.1) var look_ahead_distance: float = 1.2

var _target: Node3D


func _ready() -> void:
	_find_target()
	if is_instance_valid(_target):
		global_position = _target.global_position


func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		_find_target()
	if not is_instance_valid(_target):
		return

	var desired_position: Vector3 = _target.get_global_transform_interpolated().origin
	if _target is CharacterBody3D:
		var body: CharacterBody3D = _target as CharacterBody3D
		var horizontal_velocity: Vector3 = Vector3(body.velocity.x, 0.0, body.velocity.z)
		if horizontal_velocity.length_squared() > 0.01:
			desired_position += horizontal_velocity.normalized() * look_ahead_distance

	var follow_weight: float = 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(desired_position, follow_weight)


func _find_target() -> void:
	_target = get_tree().get_first_node_in_group(target_group) as Node3D
