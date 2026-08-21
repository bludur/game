class_name CultistEnemy
extends CharacterBody3D

signal state_changed(previous_state: int, next_state: int)
signal attacked(damage: float)
signal defeated(enemy: Node)

enum State {
	IDLE,
	APPROACH,
	KEEP_DISTANCE,
	RETREAT,
	DEAD,
}

@export_group("Movement")
@export_range(0.5, 12.0, 0.1) var move_speed: float = 2.7
@export_range(2.0, 30.0, 0.5) var aggro_range: float = 16.0
@export_range(2.0, 40.0, 0.5) var disengage_range: float = 20.0
@export_range(1.0, 12.0, 0.25) var retreat_distance: float = 4.25
@export_range(2.0, 16.0, 0.25) var preferred_distance: float = 7.0
@export_range(1.0, 30.0, 0.5) var turn_speed: float = 9.0

@export_group("Combat")
@export var projectile_scene: PackedScene
@export_range(1.0, 100.0, 1.0) var attack_damage: float = 7.0
@export_range(0.2, 5.0, 0.05) var attack_cooldown: float = 1.65
@export_range(2.0, 30.0, 0.5) var attack_range: float = 10.0
@export_range(1.0, 40.0, 0.5) var projectile_speed: float = 11.0

var current_state: State = State.IDLE
var _target: MagePlayer
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
@onready var _glow: OmniLight3D = get_node("Visuals/Glow") as OmniLight3D
@onready var _cast_origin: Marker3D = get_node("CastOrigin") as Marker3D
@onready var _animation_player: AnimationPlayer = get_node("AnimationPlayer") as AnimationPlayer
@onready var _attack_timer: Timer = get_node("AttackTimer") as Timer
@onready var _target_refresh_timer: Timer = get_node("TargetRefreshTimer") as Timer
@onready var _sfx_pool: SfxPool3D = get_node("SfxPool3D") as SfxPool3D


func _ready() -> void:
	_hurtbox.bind_health(_health)
	_hurt_sound = SyntheticAudio.create_hurt()
	_death_sound = SyntheticAudio.create_death()
	_attack_sound = SyntheticAudio.create_enemy_attack()
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	_target_refresh_timer.timeout.connect(_refresh_navigation_target)
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

	_update_state_from_distance()
	match current_state:
		State.IDLE, State.KEEP_DISTANCE:
			_stop_horizontal(delta)
		State.APPROACH, State.RETREAT:
			_move_toward_navigation(delta)
		_:
			velocity.x = 0.0
			velocity.z = 0.0

	if is_instance_valid(_target):
		var facing: Vector3 = _target.global_position - global_position
		facing.y = 0.0
		_face_direction(facing.normalized(), delta)
	if current_state == State.KEEP_DISTANCE and _attack_timer.is_stopped():
		try_attack()
	move_and_slide()


func get_health_component() -> HealthComponent:
	return _health


func get_hurtbox_component() -> HurtboxComponent:
	return _hurtbox


func get_movement_multiplier() -> float:
	return _movement_modifier.get_multiplier()


func get_state_name() -> StringName:
	return StringName(State.keys()[current_state].to_lower())


func set_combat_target(target: MagePlayer) -> void:
	_target = target
	_refresh_navigation_target()


func try_attack() -> bool:
	if current_state == State.DEAD or not is_instance_valid(_target):
		return false
	if not _attack_timer.is_stopped() or projectile_scene == null:
		return false
	if global_position.distance_to(_target.global_position) > attack_range:
		return false
	var projectile_node: Node = projectile_scene.instantiate()
	if projectile_node is not CultistBolt:
		projectile_node.queue_free()
		return false
	var spawn_parent: Node = get_tree().current_scene
	if not is_instance_valid(spawn_parent):
		spawn_parent = get_parent()
	spawn_parent.add_child(projectile_node)
	var projectile: CultistBolt = projectile_node as CultistBolt
	projectile.global_position = _cast_origin.global_position
	var target_position: Vector3 = _target.global_position + Vector3.UP * 0.9
	projectile.configure(
		target_position - _cast_origin.global_position,
		attack_damage,
		projectile_speed,
		attack_range + 2.0,
		self,
		&"enemy"
	)
	_animation_player.stop()
	_animation_player.play(&"attack", 0.05)
	_sfx_pool.play_sfx(_attack_sound, -3.0)
	_attack_timer.start(attack_cooldown)
	attacked.emit(attack_damage)
	return true


func _update_state_from_distance() -> void:
	if not is_instance_valid(_target) or not _target.get_health_component().is_alive():
		_transition_to(State.IDLE)
		return
	var distance_to_target: float = global_position.distance_to(_target.global_position)
	if distance_to_target > disengage_range:
		_transition_to(State.IDLE)
	elif distance_to_target < retreat_distance:
		_transition_to(State.RETREAT)
	elif distance_to_target > preferred_distance:
		_transition_to(State.APPROACH)
	else:
		_transition_to(State.KEEP_DISTANCE)


func _move_toward_navigation(delta: float) -> void:
	var direction: Vector3 = Vector3.ZERO
	var map_rid: RID = _navigation_agent.get_navigation_map()
	if map_rid.is_valid() and NavigationServer3D.map_get_iteration_id(map_rid) > 0 \
		and not _navigation_agent.is_navigation_finished():
		direction = _navigation_agent.get_next_path_position() - global_position
	elif is_instance_valid(_target):
		direction = _target.global_position - global_position
		if current_state == State.RETREAT:
			direction = -direction
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		_stop_horizontal(delta)
		return
	direction = direction.normalized()
	var effective_speed: float = move_speed * _movement_modifier.get_multiplier()
	velocity.x = move_toward(velocity.x, direction.x * effective_speed, effective_speed * 8.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * effective_speed, effective_speed * 8.0 * delta)


func _stop_horizontal(delta: float) -> void:
	var deceleration: float = move_speed * 10.0 * delta
	velocity.x = move_toward(velocity.x, 0.0, deceleration)
	velocity.z = move_toward(velocity.z, 0.0, deceleration)


func _face_direction(direction: Vector3, delta: float) -> void:
	if direction.length_squared() <= 0.001:
		return
	var target_yaw: float = atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))


func _refresh_navigation_target() -> void:
	if not is_instance_valid(_target):
		var player_node: Node = get_tree().get_first_node_in_group(&"player")
		if player_node is MagePlayer:
			_target = player_node as MagePlayer
	if not is_instance_valid(_target) or current_state == State.DEAD:
		return
	if current_state == State.RETREAT:
		var away: Vector3 = global_position - _target.global_position
		away.y = 0.0
		if away.length_squared() <= 0.001:
			away = Vector3.RIGHT
		var retreat_target: Vector3 = global_position + away.normalized() * 4.0
		retreat_target.x = clampf(retreat_target.x, -10.0, 10.0)
		retreat_target.z = clampf(retreat_target.z, -10.0, 10.0)
		_navigation_agent.target_position = retreat_target
	else:
		_navigation_agent.target_position = _target.global_position


func _transition_to(next_state: State) -> void:
	if current_state == next_state:
		return
	var previous_state: State = current_state
	current_state = next_state
	_enter_state(next_state)
	state_changed.emit(previous_state, current_state)
	_refresh_navigation_target()


func _enter_state(state: State) -> void:
	match state:
		State.IDLE, State.KEEP_DISTANCE:
			_animation_player.play(&"idle", 0.12)
		State.APPROACH, State.RETREAT:
			_animation_player.play(&"move", 0.12)
		State.DEAD:
			velocity = Vector3.ZERO
			_animation_player.stop()
			_animation_player.play(&"death", 0.06)
		_:
			pass


func _on_damaged(_amount: float) -> void:
	_sfx_pool.play_sfx(_hurt_sound, -4.0)
	if _glow_tween != null:
		_glow_tween.kill()
	_glow.light_energy = 5.0
	_glow_tween = create_tween()
	_glow_tween.tween_property(_glow, "light_energy", 2.0, 0.2)
	if current_state == State.IDLE and is_instance_valid(_target):
		_transition_to(State.APPROACH)


func _on_died() -> void:
	_sfx_pool.play_sfx(_death_sound)
	_transition_to(State.DEAD)
	collision_layer = 0
	_hurtbox.set_deferred("monitoring", false)
	_hurtbox.set_deferred("monitorable", false)
	defeated.emit(self)


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"attack" and current_state != State.DEAD:
		_animation_player.play(&"idle", 0.08)
	elif animation_name == &"death" and current_state == State.DEAD:
		queue_free()


func _build_placeholder_animations() -> void:
	if _animation_player.has_animation(&"idle"):
		return
	var library: AnimationLibrary = AnimationLibrary.new()
	var idle: Animation = Animation.new()
	idle.length = 1.0
	idle.loop_mode = Animation.LOOP_LINEAR
	_add_scale_track(idle, PackedFloat32Array([0.0, 0.5, 1.0]), [Vector3.ONE, Vector3(1.04, 0.96, 1.04), Vector3.ONE])
	var move: Animation = Animation.new()
	move.length = 0.45
	move.loop_mode = Animation.LOOP_LINEAR
	_add_scale_track(move, PackedFloat32Array([0.0, 0.225, 0.45]), [Vector3.ONE, Vector3(0.94, 1.06, 0.94), Vector3.ONE])
	var attack: Animation = Animation.new()
	attack.length = 0.32
	_add_scale_track(attack, PackedFloat32Array([0.0, 0.12, 0.32]), [Vector3.ONE, Vector3(1.25, 0.9, 1.25), Vector3.ONE])
	var death: Animation = Animation.new()
	death.length = 0.45
	_add_scale_track(death, PackedFloat32Array([0.0, 0.45]), [Vector3.ONE, Vector3.ONE * 0.05])
	library.add_animation(&"idle", idle)
	library.add_animation(&"move", move)
	library.add_animation(&"attack", attack)
	library.add_animation(&"death", death)
	_animation_player.add_animation_library(&"", library)


func _add_scale_track(animation: Animation, times: PackedFloat32Array, values: Array[Variant]) -> void:
	var track_index: int = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_index, NodePath("Visuals:scale"))
	animation.track_set_interpolation_type(track_index, Animation.INTERPOLATION_CUBIC)
	for key_index: int in range(times.size()):
		animation.track_insert_key(track_index, times[key_index], values[key_index])
