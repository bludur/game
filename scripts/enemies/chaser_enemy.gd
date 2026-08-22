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
@export var attack_telegraph: EnemyTelegraphData
@export_range(1.0, 100.0, 1.0) var attack_damage: float = 8.0
@export_range(0.2, 5.0, 0.05) var attack_cooldown: float = 1.0
@export_range(0.5, 10.0, 0.1) var respawn_delay: float = 3.5
@export var respawns: bool = true

var current_state: State = State.IDLE
var ecology_role_id: StringName = &"shadow_stalker"
var mutation_id: StringName = &""
var trophy_item_id: StringName = &"soul_shard"
var knowledge_id: StringName = &""
var _target: MagePlayer
var _spawn_transform: Transform3D
var _original_collision_layer: int
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))
var _hurt_sound: AudioStreamWAV
var _death_sound: AudioStreamWAV
var _attack_sound: AudioStreamWAV
var _glow_tween: Tween
var _role_audio_pitch: float = 1.0
var _patrol_points: Array[Vector3] = []
var _patrol_index: int = 0
var _investigation_position: Vector3 = Vector3.ZERO
var _has_investigation: bool = false
var _base_health: float = 1.0
var _base_damage: float = 1.0
var _base_speed: float = 1.0
var _base_attack_range: float = 1.0

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
@onready var _telegraph: EnemyTelegraphComponent = get_node("EnemyTelegraphComponent") as EnemyTelegraphComponent


func _ready() -> void:
	_spawn_transform = global_transform
	_original_collision_layer = collision_layer
	_hurtbox.bind_health(_health)
	_hurt_sound = SyntheticAudio.create_hurt()
	_death_sound = SyntheticAudio.create_death()
	_attack_sound = SyntheticAudio.create_enemy_attack()
	_base_health = _health.max_health
	_base_damage = attack_damage
	_base_speed = move_speed
	_base_attack_range = attack_range
	_telegraph.bind(_sfx_pool)
	_telegraph.danger_started.connect(_on_telegraph_danger_started)
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
			_update_idle(delta)
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


func configure_ecology(role: EnemyRoleData, mutation: EnemyMutationData = null) -> void:
	if role == null:
		return
	ecology_role_id = role.role_id
	trophy_item_id = role.trophy_item_id
	knowledge_id = role.knowledge_id
	_role_audio_pitch = role.audio_pitch
	var mutation_health: float = mutation.health_multiplier if mutation != null else 1.0
	var mutation_damage: float = mutation.damage_multiplier if mutation != null else 1.0
	var mutation_speed: float = mutation.speed_multiplier if mutation != null else 1.0
	move_speed = _base_speed * role.speed_multiplier * mutation_speed
	attack_damage = _base_damage * role.damage_multiplier * mutation_damage
	attack_range = _base_attack_range * role.range_multiplier
	_health.set_max_health(_base_health * role.health_multiplier * mutation_health, true)
	_visuals.scale = role.silhouette_scale
	_glow.light_color = mutation.signature_color if mutation != null else role.signature_color
	mutation_id = mutation.mutation_id if mutation != null else &""
	if mutation != null:
		_add_mutation_mark(mutation.signature_color)


func set_patrol_route(points: Array[Vector3]) -> void:
	_patrol_points = points.duplicate()
	_patrol_index = 0
	_refresh_navigation_target()


func investigate(world_position: Vector3) -> void:
	if current_state == State.DEAD:
		return
	_investigation_position = world_position
	_has_investigation = true
	if current_state == State.IDLE:
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
	_sfx_pool.play_sfx(_attack_sound, -2.0, _role_audio_pitch)
	_attack_timer.start(attack_cooldown)
	attacked.emit(attack_damage)
	return true


func _update_idle(delta: float) -> void:
	var effective_speed: float = move_speed * _movement_modifier.get_multiplier()
	if _target_is_in_range(aggro_range):
		_transition_to(State.CHASE)
		return
	if _has_investigation or not _patrol_points.is_empty():
		_update_roaming(delta, effective_speed * 0.55)
		return
	velocity.x = move_toward(velocity.x, 0.0, effective_speed)
	velocity.z = move_toward(velocity.z, 0.0, effective_speed)


func _update_roaming(delta: float, roaming_speed: float) -> void:
	var target_position: Vector3 = _investigation_position if _has_investigation \
		else _patrol_points[_patrol_index]
	var direction: Vector3 = _navigation_agent.get_next_path_position() - global_position
	if direction.length_squared() <= 0.01:
		direction = target_position - global_position
	direction.y = 0.0
	if global_position.distance_squared_to(target_position) <= 1.6:
		if _has_investigation:
			_has_investigation = false
		elif not _patrol_points.is_empty():
			_patrol_index = wrapi(_patrol_index + 1, 0, _patrol_points.size())
		_refresh_navigation_target()
		velocity.x = 0.0
		velocity.z = 0.0
		_animator.set_moving(false)
		return
	if direction.length_squared() <= 0.001:
		return
	direction = direction.normalized()
	velocity.x = move_toward(velocity.x, direction.x * roaming_speed, roaming_speed * 6.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * roaming_speed, roaming_speed * 6.0 * delta)
	_face_direction(direction, delta)
	_animator.set_moving(true)


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

	var direction: Vector3
	var map_rid: RID = _navigation_agent.get_navigation_map()
	if map_rid.is_valid() and NavigationServer3D.map_get_iteration_id(map_rid) > 0 \
			and not _navigation_agent.is_navigation_finished():
		direction = _navigation_agent.get_next_path_position() - global_position
	else:
		direction = _target.global_position - global_position
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
		_request_telegraphed_attack()


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
	if current_state == State.DEAD:
		return
	if current_state == State.IDLE and _has_investigation:
		_navigation_agent.target_position = _investigation_position
	elif current_state == State.IDLE and not _patrol_points.is_empty():
		_navigation_agent.target_position = _patrol_points[_patrol_index]
	elif is_instance_valid(_target):
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
				_request_telegraphed_attack()
		State.DEAD:
			velocity = Vector3.ZERO
			_animator.play_death()
		_:
			pass


func _exit_state(_state: State) -> void:
	if _state == State.ATTACK:
		_telegraph.finish()


func _request_telegraphed_attack() -> bool:
	if attack_telegraph == null or not is_instance_valid(_target) \
			or global_position.distance_to(_target.global_position) > attack_range:
		return false
	return _telegraph.begin_at(global_position, attack_telegraph)


func _on_telegraph_danger_started(_definition: EnemyTelegraphData) -> void:
	try_attack()


func _on_damaged(_amount: float) -> void:
	_sfx_pool.play_sfx(_hurt_sound, -3.0, _role_audio_pitch)
	_animator.play_hit()
	if _glow_tween != null:
		_glow_tween.kill()
	_glow.light_energy = 4.5
	_glow_tween = create_tween()
	_glow_tween.tween_property(_glow, "light_energy", 1.8, 0.2)
	if current_state == State.IDLE and is_instance_valid(_target):
		_transition_to(State.CHASE)


func _on_died() -> void:
	_telegraph.finish()
	_sfx_pool.play_sfx(_death_sound, 0.0, _role_audio_pitch)
	_transition_to(State.DEAD)
	collision_layer = 0
	_hurtbox.set_deferred("monitoring", false)
	_hurtbox.set_deferred("monitorable", false)
	defeated.emit(self)
	if respawns:
		_respawn_timer.start(respawn_delay)


func _on_respawn_timeout() -> void:
	_telegraph.finish()
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


func _add_mutation_mark(color: Color) -> void:
	var mark: MeshInstance3D = MeshInstance3D.new()
	mark.name = "MutationMark"
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 0.66
	torus.rings = 16
	torus.ring_segments = 4
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.8
	torus.material = material
	mark.mesh = torus
	mark.position.y = 1.7
	_visuals.add_child(mark)
