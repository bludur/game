class_name ChaserEnemy
extends CharacterBody3D

signal state_changed(previous_state: int, next_state: int)
signal attacked(damage: float)
signal respawned()

enum State {
	IDLE,
	CHASE,
	ATTACK,
	DEAD,
}

@export_group("Movement")
@export_range(0.5, 12.0, 0.1) var move_speed: float = 3.2
@export_range(2.0, 30.0, 0.5) var aggro_range: float = 12.0
@export_range(2.0, 40.0, 0.5) var disengage_range: float = 16.0
@export_range(0.5, 5.0, 0.05) var attack_range: float = 1.55
@export_range(1.0, 30.0, 0.5) var turn_speed: float = 10.0

@export_group("Combat")
@export_range(1.0, 100.0, 1.0) var attack_damage: float = 8.0
@export_range(0.2, 5.0, 0.05) var attack_cooldown: float = 1.0
@export_range(0.5, 10.0, 0.1) var respawn_delay: float = 3.5

var current_state: State = State.IDLE
var _target: MagePlayer
var _spawn_transform: Transform3D
var _original_collision_layer: int
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))

@onready var _navigation_agent: NavigationAgent3D = get_node("NavigationAgent3D") as NavigationAgent3D
@onready var _health: HealthComponent = get_node("HealthComponent") as HealthComponent
@onready var _hurtbox: HurtboxComponent = get_node("HurtboxComponent") as HurtboxComponent
@onready var _visuals: Node3D = get_node("Visuals") as Node3D
@onready var _animation_player: AnimationPlayer = get_node("AnimationPlayer") as AnimationPlayer
@onready var _attack_timer: Timer = get_node("AttackTimer") as Timer
@onready var _target_refresh_timer: Timer = get_node("TargetRefreshTimer") as Timer
@onready var _respawn_timer: Timer = get_node("RespawnTimer") as Timer


func _ready() -> void:
	_spawn_transform = global_transform
	_original_collision_layer = collision_layer
	_hurtbox.bind_health(_health)
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	_target_refresh_timer.timeout.connect(_refresh_navigation_target)
	_respawn_timer.timeout.connect(_on_respawn_timeout)
	_animation_player.animation_finished.connect(_on_animation_finished)
	_build_placeholder_animations()
	_enter_state(State.IDLE)
	call_deferred("_refresh_navigation_target")


func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = -0.5
	else:
		velocity.y -= _gravity * delta

	match current_state:
		State.IDLE:
			_update_idle()
		State.CHASE:
			_update_chase(delta)
		State.ATTACK:
			_update_attack(delta)
		_:
			velocity.x = 0.0
			velocity.z = 0.0

	move_and_slide()


func get_health_component() -> HealthComponent:
	return _health


func get_hurtbox_component() -> HurtboxComponent:
	return _hurtbox


func get_state_name() -> StringName:
	match current_state:
		State.IDLE:
			return &"idle"
		State.CHASE:
			return &"chase"
		State.ATTACK:
			return &"attack"
		State.DEAD:
			return &"dead"
		_:
			return &"unknown"


func set_combat_target(target: MagePlayer) -> void:
	_target = target
	_refresh_navigation_target()


func try_attack() -> bool:
	if current_state == State.DEAD or not is_instance_valid(_target):
		return false
	if not _attack_timer.is_stopped():
		return false
	if global_position.distance_to(_target.global_position) > attack_range:
		return false
	var target_hurtbox: HurtboxComponent = _target.get_hurtbox_component()
	if not is_instance_valid(target_hurtbox) or not target_hurtbox.receive_hit(attack_damage):
		return false

	_animation_player.stop()
	_animation_player.play(&"attack", 0.08)
	_attack_timer.start(attack_cooldown)
	attacked.emit(attack_damage)
	return true


func _update_idle() -> void:
	velocity.x = move_toward(velocity.x, 0.0, move_speed)
	velocity.z = move_toward(velocity.z, 0.0, move_speed)
	if _target_is_in_range(aggro_range):
		_transition_to(State.CHASE)


func _update_chase(delta: float) -> void:
	if not is_instance_valid(_target) or not _target.get_health_component().is_alive():
		_transition_to(State.IDLE)
		return

	var target_distance: float = global_position.distance_to(_target.global_position)
	if target_distance <= attack_range:
		_transition_to(State.ATTACK)
		return
	if target_distance > disengage_range:
		_transition_to(State.IDLE)
		return

	if _navigation_agent.is_navigation_finished():
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var next_path_position: Vector3 = _navigation_agent.get_next_path_position()
	var direction: Vector3 = next_path_position - global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		velocity.x = 0.0
		velocity.z = 0.0
		return

	direction = direction.normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	_face_direction(direction, delta)


func _update_attack(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_instance_valid(_target) or not _target.get_health_component().is_alive():
		_transition_to(State.IDLE)
		return
	if global_position.distance_to(_target.global_position) > attack_range:
		_transition_to(State.CHASE)
		return

	var target_direction: Vector3 = _target.global_position - global_position
	target_direction.y = 0.0
	_face_direction(target_direction.normalized(), delta)
	if _attack_timer.is_stopped():
		try_attack()


func _face_direction(direction: Vector3, delta: float) -> void:
	if direction.length_squared() <= 0.001:
		return
	var target_yaw: float = atan2(-direction.x, -direction.z)
	var turn_weight: float = 1.0 - exp(-turn_speed * delta)
	rotation.y = lerp_angle(rotation.y, target_yaw, turn_weight)


func _target_is_in_range(distance: float) -> bool:
	return is_instance_valid(_target) \
		and _target.get_health_component().is_alive() \
		and global_position.distance_to(_target.global_position) <= distance


func _refresh_navigation_target() -> void:
	if not is_instance_valid(_target):
		var player_node: Node = get_tree().get_first_node_in_group(&"player")
		if player_node is MagePlayer:
			_target = player_node as MagePlayer
	if is_instance_valid(_target) and current_state != State.DEAD:
		_navigation_agent.target_position = _target.global_position


func _transition_to(next_state: State) -> void:
	if current_state == next_state:
		return
	var previous_state: State = current_state
	_exit_state(current_state)
	current_state = next_state
	_enter_state(current_state)
	state_changed.emit(previous_state, current_state)


func _enter_state(state: State) -> void:
	match state:
		State.IDLE:
			_animation_player.play(&"idle", 0.15)
		State.CHASE:
			_animation_player.play(&"chase", 0.12)
		State.ATTACK:
			if _attack_timer.is_stopped():
				try_attack()
		State.DEAD:
			velocity = Vector3.ZERO
			_animation_player.stop()
			_animation_player.play(&"death", 0.08)
		_:
			pass


func _exit_state(_state: State) -> void:
	pass


func _on_damaged(_amount: float) -> void:
	if current_state == State.IDLE and is_instance_valid(_target):
		_transition_to(State.CHASE)


func _on_died() -> void:
	_transition_to(State.DEAD)
	collision_layer = 0
	_hurtbox.set_deferred("monitoring", false)
	_hurtbox.set_deferred("monitorable", false)
	_respawn_timer.start(respawn_delay)


func _on_respawn_timeout() -> void:
	global_transform = _spawn_transform
	reset_physics_interpolation()
	_health.reset()
	_visuals.position = Vector3.ZERO
	_visuals.rotation = Vector3.ZERO
	_visuals.scale = Vector3.ONE
	_visuals.visible = true
	collision_layer = _original_collision_layer
	_hurtbox.set_deferred("monitoring", true)
	_hurtbox.set_deferred("monitorable", true)
	_transition_to(State.IDLE)
	_refresh_navigation_target()
	respawned.emit()


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"attack" and current_state == State.ATTACK:
		_animation_player.play(&"idle", 0.08)
	elif animation_name == &"death" and current_state == State.DEAD:
		_visuals.visible = false


func _build_placeholder_animations() -> void:
	if _animation_player.has_animation(&"idle"):
		return

	var library: AnimationLibrary = AnimationLibrary.new()
	library.add_animation(&"RESET", _create_reset_animation())
	library.add_animation(&"idle", _create_idle_animation())
	library.add_animation(&"chase", _create_chase_animation())
	library.add_animation(&"attack", _create_attack_animation())
	library.add_animation(&"death", _create_death_animation())
	_animation_player.add_animation_library(&"", library)


func _create_reset_animation() -> Animation:
	var animation: Animation = Animation.new()
	animation.length = 0.0
	_add_value_track(
		animation,
		NodePath("Visuals:position"),
		PackedFloat32Array([0.0]),
		[Vector3.ZERO]
	)
	_add_value_track(
		animation,
		NodePath("Visuals:rotation"),
		PackedFloat32Array([0.0]),
		[Vector3.ZERO]
	)
	_add_value_track(
		animation,
		NodePath("Visuals:scale"),
		PackedFloat32Array([0.0]),
		[Vector3.ONE]
	)
	return animation


func _create_idle_animation() -> Animation:
	var animation: Animation = Animation.new()
	animation.length = 1.2
	animation.loop_mode = Animation.LOOP_LINEAR
	_add_value_track(
		animation,
		NodePath("Visuals:position"),
		PackedFloat32Array([0.0, 0.6, 1.2]),
		[Vector3.ZERO, Vector3(0.0, 0.1, 0.0), Vector3.ZERO]
	)
	return animation


func _create_chase_animation() -> Animation:
	var animation: Animation = Animation.new()
	animation.length = 0.42
	animation.loop_mode = Animation.LOOP_LINEAR
	_add_value_track(
		animation,
		NodePath("Visuals:scale"),
		PackedFloat32Array([0.0, 0.21, 0.42]),
		[Vector3.ONE, Vector3(1.08, 0.92, 1.08), Vector3.ONE]
	)
	return animation


func _create_attack_animation() -> Animation:
	var animation: Animation = Animation.new()
	animation.length = 0.34
	_add_value_track(
		animation,
		NodePath("Visuals:scale"),
		PackedFloat32Array([0.0, 0.12, 0.34]),
		[Vector3.ONE, Vector3(1.35, 0.82, 1.35), Vector3.ONE]
	)
	return animation


func _create_death_animation() -> Animation:
	var animation: Animation = Animation.new()
	animation.length = 0.45
	_add_value_track(
		animation,
		NodePath("Visuals:rotation"),
		PackedFloat32Array([0.0, 0.45]),
		[Vector3.ZERO, Vector3(0.0, 0.0, 1.35)]
	)
	_add_value_track(
		animation,
		NodePath("Visuals:scale"),
		PackedFloat32Array([0.0, 0.45]),
		[Vector3.ONE, Vector3.ONE * 0.05]
	)
	return animation


func _add_value_track(
	animation: Animation,
	property_path: NodePath,
	times: PackedFloat32Array,
	values: Array[Variant]
) -> void:
	var track_index: int = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_index, property_path)
	animation.track_set_interpolation_type(track_index, Animation.INTERPOLATION_CUBIC)
	for key_index: int in range(times.size()):
		animation.track_insert_key(track_index, times[key_index], values[key_index])
