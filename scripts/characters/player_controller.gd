class_name PlayerController
extends Node

@export_group("Movement")
@export_range(1.0, 20.0, 0.1) var move_speed: float = 6.0
@export_range(1.0, 60.0, 0.5) var acceleration: float = 28.0
@export_range(1.0, 60.0, 0.5) var deceleration: float = 34.0
@export_range(1.0, 30.0, 0.5) var visual_turn_speed: float = 14.0

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))
var _body: CharacterBody3D
var _visuals: Node3D


func _ready() -> void:
	set_physics_process(false)


func bind(body: CharacterBody3D, visuals: Node3D) -> void:
	_body = body
	_visuals = visuals
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_body) or not is_instance_valid(_visuals):
		return

	var input_vector: Vector2 = Input.get_vector(
		&"move_left",
		&"move_right",
		&"move_forward",
		&"move_backward"
	)
	var move_direction: Vector3 = _camera_relative_direction(input_vector)
	var horizontal_velocity: Vector3 = Vector3(_body.velocity.x, 0.0, _body.velocity.z)
	var target_velocity: Vector3 = move_direction * move_speed
	var change_rate: float = acceleration if move_direction != Vector3.ZERO else deceleration

	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, change_rate * delta)
	_body.velocity.x = horizontal_velocity.x
	_body.velocity.z = horizontal_velocity.z

	if _body.is_on_floor():
		if _body.velocity.y < 0.0:
			_body.velocity.y = -0.5
	else:
		_body.velocity.y -= _gravity * delta

	_body.move_and_slide()
	_rotate_visuals(move_direction, delta)


func _camera_relative_direction(input_vector: Vector2) -> Vector3:
	if input_vector == Vector2.ZERO:
		return Vector3.ZERO

	var active_camera: Camera3D = get_viewport().get_camera_3d()
	if active_camera == null:
		return Vector3(input_vector.x, 0.0, input_vector.y).normalized()

	var camera_right: Vector3 = active_camera.global_basis.x
	var camera_forward: Vector3 = -active_camera.global_basis.z
	camera_right.y = 0.0
	camera_forward.y = 0.0
	camera_right = camera_right.normalized()
	camera_forward = camera_forward.normalized()

	return (camera_right * input_vector.x + camera_forward * -input_vector.y).normalized()


func _rotate_visuals(move_direction: Vector3, delta: float) -> void:
	if move_direction == Vector3.ZERO:
		return

	var target_yaw: float = atan2(-move_direction.x, -move_direction.z)
	var turn_weight: float = 1.0 - exp(-visual_turn_speed * delta)
	_visuals.rotation.y = lerp_angle(_visuals.rotation.y, target_yaw, turn_weight)
