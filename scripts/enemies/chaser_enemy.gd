class_name ChaserEnemy
extends CharacterBody3D

signal state_changed(previous_state: int, next_state: int)
signal attacked(damage: float)
signal respawned()
signal defeated(enemy: Node)

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
@export var respawns: bool = true

var current_state: State = State.IDLE
var _target: MagePlayer
var _spawn_transform: Transform3D
var _original_collision_layer: int
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))
var _hurt_sound: AudioStreamWAV
var _death_sound: AudioStreamWAV
var _attack_sound: AudioStreamWAV
var _glow_tween: Tween

@onready var _navigation_agent: NavigationAgent3D = get_node("NavigationAgent3D") as NavigationAgent3D
@onready var _health: HealthComponent = get_node("HealthComponent") as HealthComponent
@onready var _hurtbox: HurtboxComponent = get_node("HurtboxComponent") as HurtboxComponent
@onready var _movement_modifier: MovementModifierComponent = get_node("MovementModifierComponent") as MovementModifierComponent
@onready var _visuals: Node3D = get_node("Visuals") as Node3D
@onready var _animator: CharacterAnimator = get_node("CharacterAnimator") as CharacterAnimator
@onready var _glow: OmniLight3D = get_node("Visuals/Glow") as OmniLight3D
@onready var _sfx_pool: SfxPool3D = get_node("SfxPool3D") as SfxPool3D
@onready var _attack_timer: Timer = get_node("AttackTimer") as Timer
@onready var _target_refresh_timer: Timer = get_node("TargetRefreshTimer") as Timer
@onready var _respawn_timer: Timer = get_node("RespawnTimer") as Timer


func _ready() -> void:
	_spawn_transform = global_transform
	_original_collision_layer = collision_layer
	_hurtbox.bind_health(_health)
	_hurt_sound = SyntheticAudio.create_hurt()
	_death_sound = SyntheticAudio.create_death()
	_attack_sound = SyntheticAudio.create_enemy_attack()
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	_target_refresh_timer.timeout.connect(_refresh_navigation_target)
	_respawn_timer.timeout.connect(_on_respawn_timeout)
	_animator.animation_finished.connect(_on_animation_finished)
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


func get_movement_multiplier() -> float:
	return _movement_modifier.get_multiplier()


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

	_animator.play_cast()
	_sfx_pool.play_sfx(_attack_sound, -2.0)
	_attack_timer.start(attack_cooldown)
	attacked.emit(attack_damage)
	return true


func _update_idle() -> void:
	var effective_speed: float = move_speed * _movement_modifier.get_multiplier()
	velocity.x = move_toward(velocity.x, 0.0, effective_speed)
	velocity.z = move_toward(velocity.z, 0.0, effective_speed)
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
	var effective_speed: float = move_speed * _movement_modifier.get_multiplier()
	velocity.x = direction.x * effective_speed
	velocity.z = direction.z * effective_speed
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
			_animator.set_moving(false)
		State.CHASE:
			_animator.set_moving(true)
		State.ATTACK:
			if _attack_timer.is_stopped():
				try_attack()
		State.DEAD:
			velocity = Vector3.ZERO
			_animator.play_death()
		_:
			pass


func _exit_state(_state: State) -> void:
	pass


func _on_damaged(_amount: float) -> void:
	_sfx_pool.play_sfx(_hurt_sound, -3.0)
	_animator.play_hit()
	if _glow_tween != null:
		_glow_tween.kill()
	_glow.light_energy = 4.5
	_glow_tween = create_tween()
	_glow_tween.tween_property(_glow, "light_energy", 1.8, 0.2)
	if current_state == State.IDLE and is_instance_valid(_target):
		_transition_to(State.CHASE)


func _on_died() -> void:
	_sfx_pool.play_sfx(_death_sound)
	_transition_to(State.DEAD)
	collision_layer = 0
	_hurtbox.set_deferred("monitoring", false)
	_hurtbox.set_deferred("monitorable", false)
	defeated.emit(self)
	if respawns:
		_respawn_timer.start(respawn_delay)


func _on_respawn_timeout() -> void:
	global_transform = _spawn_transform
	reset_physics_interpolation()
	_health.reset()
	_movement_modifier.clear()
	_animator.reset_visual()
	_visuals.visible = true
	collision_layer = _original_collision_layer
	_hurtbox.set_deferred("monitoring", true)
	_hurtbox.set_deferred("monitorable", true)
	_transition_to(State.IDLE)
	_refresh_navigation_target()
	respawned.emit()


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"death" and current_state == State.DEAD:
		if respawns:
			_visuals.visible = false
		else:
			queue_free()
