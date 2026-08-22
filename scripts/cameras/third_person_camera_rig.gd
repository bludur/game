class_name ThirdPersonCameraRig
extends Node3D

@export_group("Target")
@export var target_group: StringName = &"player"
@export_range(0.5, 3.0, 0.05) var target_height: float = 1.45
@export_range(1.0, 40.0, 0.5) var follow_speed: float = 18.0
@export_range(2.0, 30.0, 0.5) var teleport_snap_distance: float = 10.0
@export_group("Look")
@export_range(0.0005, 0.02, 0.0005) var mouse_sensitivity: float = 0.003
@export_range(0.5, 6.0, 0.1) var gamepad_look_speed: float = 2.4
@export_range(-80.0, -10.0, 1.0) var minimum_pitch_degrees: float = -65.0
@export_range(-5.0, 45.0, 1.0) var maximum_pitch_degrees: float = 30.0
@export_range(-60.0, 20.0, 1.0) var initial_pitch_degrees: float = -14.0
@export_group("Zoom")
@export_range(2.0, 6.0, 0.25) var minimum_distance: float = 3.0
@export_range(5.0, 12.0, 0.25) var maximum_distance: float = 8.0
@export_range(0.25, 2.0, 0.25) var zoom_step: float = 0.75
@export_range(1.0, 20.0, 0.5) var zoom_speed: float = 9.0
@export_range(2.0, 10.0, 0.25) var initial_distance: float = 5.5

var _target: Node3D
var _controls_enabled: bool = true
var _follow_initialized: bool = false
var _yaw: float = 0.0
var _pitch: float = 0.0
var _desired_distance: float = 5.5

@onready var _pitch_pivot: Node3D = get_node("PitchPivot") as Node3D
@onready var _spring_arm: SpringArm3D = get_node("PitchPivot/ShoulderOffset/SpringArm3D") as SpringArm3D
@onready var _camera: Camera3D = get_node("PitchPivot/ShoulderOffset/SpringArm3D/Camera3D") as Camera3D


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	top_level = true
	_yaw = rotation.y
	_pitch = clampf(
		deg_to_rad(initial_pitch_degrees),
		deg_to_rad(minimum_pitch_degrees),
		deg_to_rad(maximum_pitch_degrees)
	)
	_desired_distance = clampf(initial_distance, minimum_distance, maximum_distance)
	_spring_arm.spring_length = _desired_distance
	_apply_rotation()
	_find_target()
	snap_to_target()
	_update_mouse_mode()


func _exit_tree() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	if not _controls_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is not InputEventMouseMotion:
		return
	var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
	_yaw = wrapf(_yaw - mouse_motion.relative.x * mouse_sensitivity, -PI, PI)
	_pitch = clampf(
		_pitch - mouse_motion.relative.y * mouse_sensitivity,
		deg_to_rad(minimum_pitch_degrees),
		deg_to_rad(maximum_pitch_degrees)
	)
	_apply_rotation()


func _unhandled_input(event: InputEvent) -> void:
	if not _controls_enabled:
		return
	if event.is_action_pressed(&"camera_zoom_in"):
		adjust_zoom(-1.0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"camera_zoom_out"):
		adjust_zoom(1.0)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		_find_target()
	if is_instance_valid(_target):
		_follow_target(delta)
	if _controls_enabled:
		_apply_gamepad_look(delta)
	_spring_arm.spring_length = move_toward(
		_spring_arm.spring_length,
		_desired_distance,
		zoom_speed * delta
	)


func set_target(target: Node3D) -> void:
	_target = target
	_follow_initialized = false
	snap_to_target()


func set_controls_enabled(enabled: bool) -> void:
	_controls_enabled = enabled
	set_process_input(enabled)
	set_process_unhandled_input(enabled)
	_update_mouse_mode()


func are_controls_enabled() -> bool:
	return _controls_enabled


func adjust_zoom(steps: float) -> void:
	_desired_distance = clampf(
		_desired_distance + steps * zoom_step,
		minimum_distance,
		maximum_distance
	)


func get_desired_distance() -> float:
	return _desired_distance


func get_camera() -> Camera3D:
	return _camera


func get_spring_arm() -> SpringArm3D:
	return _spring_arm


func get_flat_forward() -> Vector3:
	var forward: Vector3 = -_camera.global_basis.z
	forward.y = 0.0
	return forward.normalized()


func snap_to_target() -> void:
	if not is_instance_valid(_target):
		return
	global_position = _target.global_position + Vector3.UP * target_height
	_follow_initialized = true
	reset_physics_interpolation()


func _follow_target(delta: float) -> void:
	var target_transform: Transform3D = _target.get_global_transform_interpolated()
	var desired_position: Vector3 = target_transform.origin + Vector3.UP * target_height
	if not _follow_initialized or global_position.distance_to(desired_position) >= teleport_snap_distance:
		global_position = desired_position
		_follow_initialized = true
		return
	var follow_weight: float = 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(desired_position, follow_weight)


func _apply_gamepad_look(delta: float) -> void:
	var look_input: Vector2 = Input.get_vector(
		&"aim_left", &"aim_right", &"aim_up", &"aim_down"
	)
	if look_input.length_squared() <= 0.01:
		return
	_yaw = wrapf(_yaw - look_input.x * gamepad_look_speed * delta, -PI, PI)
	_pitch = clampf(
		_pitch - look_input.y * gamepad_look_speed * delta,
		deg_to_rad(minimum_pitch_degrees),
		deg_to_rad(maximum_pitch_degrees)
	)
	_apply_rotation()


func _apply_rotation() -> void:
	rotation = Vector3(0.0, _yaw, 0.0)
	_pitch_pivot.rotation = Vector3(_pitch, 0.0, 0.0)


func _find_target() -> void:
	_target = get_tree().get_first_node_in_group(target_group) as Node3D


func _update_mouse_mode() -> void:
	if not is_inside_tree():
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _controls_enabled else Input.MOUSE_MODE_VISIBLE
