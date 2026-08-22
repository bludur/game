class_name PlayerController
extends Node

signal movement_state_changed(state_name: StringName)
signal movement_activity_changed(is_moving: bool)

enum State {
	MOVE,
	DASH,
	DISABLED,
}

@export_group("Movement")
@export_range(1.0, 20.0, 0.1) var move_speed: float = 6.0
@export_range(1.0, 2.5, 0.05) var sprint_multiplier: float = 1.55
@export_range(1.0, 60.0, 0.5) var acceleration: float = 28.0
@export_range(1.0, 60.0, 0.5) var deceleration: float = 34.0
@export_range(1.0, 30.0, 0.5) var turn_speed: float = 14.0

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))
var _body: CharacterBody3D
var _visuals: Node3D
var _dash: DashComponent
var _enabled: bool = true
var _state: State = State.MOVE
var _last_move_direction: Vector3 = Vector3.FORWARD
var _was_moving: bool = false
var _facing_override_direction: Vector3 = Vector3.ZERO
var _facing_override_remaining: float = 0.0


func _ready() -> void:
	set_physics_process(false)


func bind(body: CharacterBody3D, visuals: Node3D, dash: DashComponent = null) -> void:
	_body = body
	_visuals = visuals
	_dash = dash
	if is_instance_valid(_dash) and not _dash.dash_requested.is_connected(_on_dash_requested):
		_dash.dash_requested.connect(_on_dash_requested)
		_dash.dash_started.connect(_on_dash_started)
		_dash.dash_finished.connect(_on_dash_finished)
	_transition_to(State.MOVE)
	set_physics_process(_enabled)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	set_physics_process(enabled and is_instance_valid(_body))
	if not enabled and is_instance_valid(_body):
		_body.velocity = Vector3.ZERO
		_facing_override_direction = Vector3.ZERO
		_facing_override_remaining = 0.0
	if not enabled and _was_moving:
		_was_moving = false
		movement_activity_changed.emit(false)
	_transition_to(State.MOVE if enabled else State.DISABLED)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_body) or not is_instance_valid(_visuals):
		return

	if _state == State.DASH and is_instance_valid(_dash) and _dash.is_dashing:
		_apply_gravity(delta)
		_body.velocity.x = _dash.dash_direction.x * _dash.dash_speed
		_body.velocity.z = _dash.dash_direction.z * _dash.dash_speed
		_body.move_and_slide()
		_rotate_body(_dash.dash_direction, delta)
		return

	var input_vector: Vector2 = Input.get_vector(
		&"move_left",
		&"move_right",
		&"move_forward",
		&"move_backward"
	)
	var move_direction: Vector3 = _camera_relative_direction(input_vector)
	var is_moving: bool = move_direction.length_squared() > 0.001
	if is_moving != _was_moving:
		_was_moving = is_moving
		movement_activity_changed.emit(_was_moving)
	if move_direction != Vector3.ZERO:
		_last_move_direction = move_direction
	var horizontal_velocity: Vector3 = Vector3(_body.velocity.x, 0.0, _body.velocity.z)
	var speed_multiplier: float = 1.0
	if InputMap.has_action(&"sprint") and Input.is_action_pressed(&"sprint"):
		speed_multiplier = sprint_multiplier
	var target_velocity: Vector3 = move_direction * move_speed * speed_multiplier
	var change_rate: float = acceleration if move_direction != Vector3.ZERO else deceleration

	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, change_rate * delta)
	_body.velocity.x = horizontal_velocity.x
	_body.velocity.z = horizontal_velocity.z

	_apply_gravity(delta)

	_body.move_and_slide()
	var facing_direction: Vector3 = move_direction
	if _facing_override_remaining > 0.0:
		_facing_override_remaining = maxf(0.0, _facing_override_remaining - delta)
		facing_direction = _facing_override_direction
	_rotate_body(facing_direction, delta)


func request_dash(direction: Vector3 = Vector3.ZERO) -> bool:
	if not _enabled or not is_instance_valid(_dash):
		return false
	var requested_direction: Vector3 = direction
	if requested_direction.length_squared() <= 0.001:
		var input_vector: Vector2 = Input.get_vector(
			&"move_left", &"move_right", &"move_forward", &"move_backward"
		)
		requested_direction = _camera_relative_direction(input_vector)
	if requested_direction.length_squared() <= 0.001:
		requested_direction = _last_move_direction
	return _dash.try_begin(requested_direction)


func get_state_name() -> StringName:
	match _state:
		State.MOVE:
			return &"move"
		State.DASH:
			return &"dash"
		State.DISABLED:
			return &"disabled"
		_:
			return &"unknown"


func set_facing_direction(direction: Vector3, hold_seconds: float = 0.2) -> void:
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return
	_facing_override_direction = direction.normalized()
	_facing_override_remaining = maxf(0.0, hold_seconds)


func _apply_gravity(delta: float) -> void:
	if _body.is_on_floor():
		if _body.velocity.y < 0.0:
			_body.velocity.y = -0.5
	else:
		_body.velocity.y -= _gravity * delta


func _on_dash_requested() -> void:
	request_dash()


func _on_dash_started(_direction: Vector3) -> void:
	_transition_to(State.DASH)


func _on_dash_finished() -> void:
	if _enabled:
		_transition_to(State.MOVE)


func _transition_to(next_state: State) -> void:
	if _state == next_state:
		return
	_state = next_state
	movement_state_changed.emit(get_state_name())


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


func _rotate_body(move_direction: Vector3, delta: float) -> void:
	if move_direction == Vector3.ZERO:
		return

	var target_yaw: float = atan2(-move_direction.x, -move_direction.z)
	var turn_weight: float = 1.0 - exp(-turn_speed * delta)
	_body.rotation.y = lerp_angle(_body.rotation.y, target_yaw, turn_weight)
	_visuals.rotation.y = 0.0
