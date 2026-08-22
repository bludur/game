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
@export var attack_telegraph: EnemyTelegraphData
@export_range(1.0, 100.0, 1.0) var attack_damage: float = 7.0
@export_range(0.2, 5.0, 0.05) var attack_cooldown: float = 1.65
@export_range(2.0, 30.0, 0.5) var attack_range: float = 10.0
@export_range(1.0, 40.0, 0.5) var projectile_speed: float = 11.0

var current_state: State = State.IDLE
var ecology_role_id: StringName = &"ember_ranger"
var mutation_id: StringName = &""
var trophy_item_id: StringName = &"soul_shard"
var knowledge_id: StringName = &""
var _target: MagePlayer
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
var _is_flying: bool = false
var _base_health: float = 1.0
var _base_damage: float = 1.0
var _base_speed: float = 1.0
var _base_attack_range: float = 1.0

@onready var _navigation_agent: NavigationAgent3D = get_node("NavigationAgent3D") as NavigationAgent3D
@onready var _health: HealthComponent = get_node("HealthComponent") as HealthComponent
@onready var _hurtbox: HurtboxComponent = get_node("HurtboxComponent") as HurtboxComponent
@onready var _movement_modifier: MovementModifierComponent = get_node("MovementModifierComponent") as MovementModifierComponent
@onready var _visuals: Node3D = get_node("Visuals") as Node3D
@onready var _glow: OmniLight3D = get_node("Visuals/Glow") as OmniLight3D
@onready var _cast_origin: Marker3D = get_node("CastOrigin") as Marker3D
@onready var _animator: CharacterAnimator = get_node("CharacterAnimator") as CharacterAnimator
@onready var _attack_timer: Timer = get_node("AttackTimer") as Timer
@onready var _target_refresh_timer: Timer = get_node("TargetRefreshTimer") as Timer
@onready var _sfx_pool: SfxPool3D = get_node("SfxPool3D") as SfxPool3D
@onready var _telegraph: EnemyTelegraphComponent = get_node("EnemyTelegraphComponent") as EnemyTelegraphComponent


func _ready() -> void:
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
	_animator.animation_finished.connect(_on_animation_finished)
	_enter_state(State.IDLE)
	call_deferred("_refresh_navigation_target")


func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return
	if _is_flying:
		velocity.y = 0.0
	elif is_on_floor():
		if velocity.y < 0.0:
			velocity.y = -0.5
	else:
		velocity.y -= _gravity * delta

	_update_state_from_distance()
	match current_state:
		State.IDLE:
			_update_roaming(delta)
		State.KEEP_DISTANCE:
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
		_request_telegraphed_attack()
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


func configure_ecology(role: EnemyRoleData, mutation: EnemyMutationData = null) -> void:
	if role == null:
		return
	ecology_role_id = role.role_id
	trophy_item_id = role.trophy_item_id
	knowledge_id = role.knowledge_id
	_role_audio_pitch = role.audio_pitch
	_is_flying = role.flying
	var mutation_health: float = mutation.health_multiplier if mutation != null else 1.0
	var mutation_damage: float = mutation.damage_multiplier if mutation != null else 1.0
	var mutation_speed: float = mutation.speed_multiplier if mutation != null else 1.0
	move_speed = _base_speed * role.speed_multiplier * mutation_speed
	attack_damage = _base_damage * role.damage_multiplier * mutation_damage
	attack_range = _base_attack_range * role.range_multiplier
	preferred_distance *= role.range_multiplier
	disengage_range = maxf(disengage_range, attack_range + 5.0)
	_health.set_max_health(_base_health * role.health_multiplier * mutation_health, true)
	_visuals.scale = role.silhouette_scale
	_glow.light_color = mutation.signature_color if mutation != null else role.signature_color
	mutation_id = mutation.mutation_id if mutation != null else &""
	if _is_flying:
		global_position.y += 1.8
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
	_animator.play_cast()
	_sfx_pool.play_sfx(_attack_sound, -3.0, _role_audio_pitch)
	_attack_timer.start(attack_cooldown)
	attacked.emit(attack_damage)
	return true


func _request_telegraphed_attack() -> bool:
	if attack_telegraph == null or not is_instance_valid(_target) \
			or global_position.distance_to(_target.global_position) > attack_range:
		return false
	return _telegraph.begin_at(_target.global_position, attack_telegraph)


func _on_telegraph_danger_started(_definition: EnemyTelegraphData) -> void:
	try_attack()


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


func _update_roaming(delta: float) -> void:
	if _target_is_in_aggro_range():
		return
	if not _has_investigation and _patrol_points.is_empty():
		_stop_horizontal(delta)
		return
	var target_position: Vector3 = _investigation_position if _has_investigation \
		else _patrol_points[_patrol_index]
	if global_position.distance_squared_to(target_position) <= 1.6:
		if _has_investigation:
			_has_investigation = false
		else:
			_patrol_index = wrapi(_patrol_index + 1, 0, _patrol_points.size())
		_refresh_navigation_target()
		_stop_horizontal(delta)
		_animator.set_moving(false)
		return
	var direction: Vector3 = _navigation_agent.get_next_path_position() - global_position
	if direction.length_squared() <= 0.01:
		direction = target_position - global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return
	direction = direction.normalized()
	var roaming_speed: float = move_speed * 0.52 * _movement_modifier.get_multiplier()
	velocity.x = move_toward(velocity.x, direction.x * roaming_speed, roaming_speed * 6.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * roaming_speed, roaming_speed * 6.0 * delta)
	_face_direction(direction, delta)
	_animator.set_moving(true)


func _target_is_in_aggro_range() -> bool:
	return is_instance_valid(_target) and _target.get_health_component().is_alive() \
		and global_position.distance_to(_target.global_position) <= aggro_range


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
	if current_state == State.DEAD:
		return
	if current_state == State.IDLE and _has_investigation:
		_navigation_agent.target_position = _investigation_position
	elif current_state == State.IDLE and not _patrol_points.is_empty():
		_navigation_agent.target_position = _patrol_points[_patrol_index]
	elif current_state == State.RETREAT and is_instance_valid(_target):
		var away: Vector3 = global_position - _target.global_position
		away.y = 0.0
		if away.length_squared() <= 0.001:
			away = Vector3.RIGHT
		var retreat_target: Vector3 = global_position + away.normalized() * 4.0
		retreat_target.x = clampf(retreat_target.x, -10.0, 10.0)
		retreat_target.z = clampf(retreat_target.z, -10.0, 10.0)
		_navigation_agent.target_position = retreat_target
	elif is_instance_valid(_target):
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
			_animator.set_moving(false)
		State.APPROACH, State.RETREAT:
			_animator.set_moving(true)
		State.DEAD:
			velocity = Vector3.ZERO
			_animator.play_death()
		_:
			pass


func _on_damaged(_amount: float) -> void:
	_sfx_pool.play_sfx(_hurt_sound, -4.0, _role_audio_pitch)
	_animator.play_hit()
	if _glow_tween != null:
		_glow_tween.kill()
	_glow.light_energy = 5.0
	_glow_tween = create_tween()
	_glow_tween.tween_property(_glow, "light_energy", 2.0, 0.2)
	if current_state == State.IDLE and is_instance_valid(_target):
		_transition_to(State.APPROACH)


func _on_died() -> void:
	_telegraph.finish()
	_sfx_pool.play_sfx(_death_sound, 0.0, _role_audio_pitch)
	_transition_to(State.DEAD)
	collision_layer = 0
	_hurtbox.set_deferred("monitoring", false)
	_hurtbox.set_deferred("monitorable", false)
	defeated.emit(self)


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"death" and current_state == State.DEAD:
		queue_free()


func _add_mutation_mark(color: Color) -> void:
	var mark: MeshInstance3D = MeshInstance3D.new()
	mark.name = "MutationMark"
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.48
	torus.outer_radius = 0.64
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
	mark.position.y = 1.85
	_visuals.add_child(mark)
