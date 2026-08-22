class_name ArenaWarden
extends CharacterBody3D

signal state_changed(previous_state: int, next_state: int)
signal phase_changed(phase: int)
signal telegraph_started(attack: BossAttackData)
signal attack_committed(attack: BossAttackData)
signal attack_cancelled()
signal boss_defeated(boss: ArenaWarden)

enum State {
	ENTER,
	DECIDE,
	TELEGRAPH,
	ATTACK,
	RECOVER,
	PHASE_CHANGE,
	DEFEATED,
}

@export_group("Attack Definitions")
@export var directed_strike: BossAttackData
@export var expanding_wave: BossAttackData
@export var summon_guard: BossAttackData

@export_group("Timing")
@export_range(0.1, 3.0, 0.05) var entrance_duration: float = 0.8
@export_range(0.1, 3.0, 0.05) var recovery_duration: float = 0.85
@export_range(0.1, 3.0, 0.05) var phase_change_duration: float = 1.0

@export_group("Movement")
@export_range(0.0, 8.0, 0.1) var move_speed: float = 1.8
@export_range(1.0, 30.0, 0.5) var preferred_distance: float = 5.5

var current_state: State = State.DEFEATED
var current_phase: int = 1
var _active: bool = false
var _attack_cursor: int = 0
var _current_attack: BossAttackData
var _target: MagePlayer
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))

@onready var _navigation_agent: NavigationAgent3D = get_node("NavigationAgent3D") as NavigationAgent3D
@onready var _health: HealthComponent = get_node("HealthComponent") as HealthComponent
@onready var _hurtbox: HurtboxComponent = get_node("HurtboxComponent") as HurtboxComponent
@onready var _movement_modifier: MovementModifierComponent = get_node("MovementModifierComponent") as MovementModifierComponent
@onready var _animator: CharacterAnimator = get_node("CharacterAnimator") as CharacterAnimator
@onready var _state_timer: Timer = get_node("StateTimer") as Timer
@onready var _target_refresh_timer: Timer = get_node("TargetRefreshTimer") as Timer
@onready var _telegraph_glow: OmniLight3D = get_node("Visuals/TelegraphGlow") as OmniLight3D
@onready var _sfx_pool: SfxPool3D = get_node("SfxPool3D") as SfxPool3D


func _ready() -> void:
	_hurtbox.bind_health(_health)
	_health.health_changed.connect(_on_health_changed)
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	_state_timer.timeout.connect(_on_state_timeout)
	_target_refresh_timer.timeout.connect(_refresh_navigation_target)
	_validate_attacks()
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not _active:
		return
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = -0.5
	else:
		velocity.y -= _gravity * delta

	if current_state == State.DECIDE or current_state == State.RECOVER:
		_update_movement(delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 10.0 * delta)
	move_and_slide()


func start_encounter(target: MagePlayer) -> bool:
	if not is_instance_valid(target) or not _attacks_are_valid():
		return false
	_target = target
	_active = true
	_attack_cursor = 0
	_current_attack = null
	current_phase = 1
	_health.reset()
	_hurtbox.clear_invulnerability()
	set_physics_process(true)
	_transition_to(State.ENTER)
	return true


func stop_encounter() -> void:
	_active = false
	_state_timer.stop()
	_target_refresh_timer.stop()
	velocity = Vector3.ZERO
	attack_cancelled.emit()
	set_physics_process(false)


func get_health_component() -> HealthComponent:
	return _health


func get_hurtbox_component() -> HurtboxComponent:
	return _hurtbox


func get_state_name() -> StringName:
	return StringName(State.keys()[current_state].to_lower())


func is_encounter_active() -> bool:
	return _active


func _transition_to(next_state: State) -> void:
	if current_state == next_state:
		return
	var previous_state: State = current_state
	_exit_state(current_state)
	current_state = next_state
	_enter_state(next_state)
	state_changed.emit(previous_state, next_state)


func _enter_state(state: State) -> void:
	match state:
		State.ENTER:
			_animator.play_cast()
			_state_timer.start(entrance_duration)
		State.DECIDE:
			_animator.set_moving(true)
			call_deferred("_choose_next_attack")
		State.TELEGRAPH:
			velocity.x = 0.0
			velocity.z = 0.0
			_animator.play_cast()
			_telegraph_glow.light_energy = 5.5
			telegraph_started.emit(_current_attack)
			_state_timer.start(_current_attack.telegraph_duration)
		State.ATTACK:
			attack_committed.emit(_current_attack)
			_sfx_pool.play_sfx(SyntheticAudio.create_enemy_attack(), -1.0)
			_state_timer.start(0.12)
		State.RECOVER:
			_animator.set_moving(true)
			_state_timer.start(recovery_duration * (0.72 if current_phase == 2 else 1.0))
		State.PHASE_CHANGE:
			velocity = Vector3.ZERO
			attack_cancelled.emit()
			_animator.play_hit()
			_telegraph_glow.light_color = Color(1.0, 0.08, 0.18, 1.0)
			_telegraph_glow.light_energy = 7.0
			_state_timer.start(phase_change_duration)
		State.DEFEATED:
			velocity = Vector3.ZERO
			_animator.play_death()
			_telegraph_glow.light_energy = 0.0
		_:
			pass


func _exit_state(state: State) -> void:
	if state == State.TELEGRAPH or state == State.PHASE_CHANGE:
		_telegraph_glow.light_energy = 2.0 if current_phase == 1 else 3.2


func _on_state_timeout() -> void:
	if not _active:
		return
	match current_state:
		State.ENTER:
			_transition_to(State.DECIDE)
		State.TELEGRAPH:
			_transition_to(State.ATTACK)
		State.ATTACK:
			_transition_to(State.RECOVER)
		State.RECOVER, State.PHASE_CHANGE:
			_transition_to(State.DECIDE)
		_:
			pass


func _choose_next_attack() -> void:
	if not _active or current_state != State.DECIDE:
		return
	var attacks: Array[BossAttackData] = [directed_strike, expanding_wave]
	if current_phase == 2:
		attacks.append(summon_guard)
	_current_attack = attacks[_attack_cursor % attacks.size()]
	_attack_cursor += 1
	_transition_to(State.TELEGRAPH)


func _update_movement(delta: float) -> void:
	if not is_instance_valid(_target) or not _target.get_health_component().is_alive():
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var distance: float = global_position.distance_to(_target.global_position)
	if distance <= preferred_distance:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 8.0 * delta)
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
		return
	direction = direction.normalized()
	var effective_speed: float = move_speed * _movement_modifier.get_multiplier()
	velocity.x = move_toward(velocity.x, direction.x * effective_speed, effective_speed * 6.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * effective_speed, effective_speed * 6.0 * delta)
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-8.0 * delta))


func _refresh_navigation_target() -> void:
	if _active and is_instance_valid(_target):
		_navigation_agent.target_position = _target.global_position


func _on_health_changed(current: float, maximum: float) -> void:
	if _active and current > 0.0 and current_phase == 1 and current <= maximum * 0.5:
		current_phase = 2
		phase_changed.emit(current_phase)
		_transition_to(State.PHASE_CHANGE)


func _on_damaged(_amount: float) -> void:
	if _active and current_state != State.PHASE_CHANGE:
		_animator.play_hit()
		_sfx_pool.play_sfx(SyntheticAudio.create_hurt(), -2.0)


func _on_died() -> void:
	if not _active:
		return
	_active = false
	_state_timer.stop()
	_target_refresh_timer.stop()
	attack_cancelled.emit()
	_transition_to(State.DEFEATED)
	collision_layer = 0
	_hurtbox.set_deferred("monitoring", false)
	_hurtbox.set_deferred("monitorable", false)
	boss_defeated.emit(self)


func _validate_attacks() -> void:
	if not _attacks_are_valid():
		push_error("ArenaWarden requires three valid attack definitions.")


func _attacks_are_valid() -> bool:
	return directed_strike != null and directed_strike.is_valid_definition() \
		and expanding_wave != null and expanding_wave.is_valid_definition() \
		and summon_guard != null and summon_guard.is_valid_definition()
