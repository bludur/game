class_name WardComponent
extends Node

signal active_changed(active: bool)
signal damage_blocked(incoming_damage: float, received_damage: float)
signal ward_broken()

@export_range(0.0, 100.0, 0.5) var activation_stamina_cost: float = 8.0
@export_range(0.0, 100.0, 0.5) var stamina_per_second: float = 9.0
@export_range(0.0, 100.0, 0.5) var mana_per_second: float = 11.0
@export_range(0.0, 2.0, 0.05) var stamina_per_blocked_damage: float = 0.35
@export_range(0.0, 0.95, 0.05) var damage_reduction: float = 0.75

var is_active: bool = false
var _guard_requested: bool = false
var _enabled: bool = true
var _stamina: StaminaComponent
var _mana: ManaComponent
var _combat_state: CombatStateComponent


func bind(
	stamina: StaminaComponent,
	mana: ManaComponent,
	combat_state: CombatStateComponent
) -> void:
	_stamina = stamina
	_mana = mana
	_combat_state = combat_state
	if is_instance_valid(_combat_state) \
			and not _combat_state.state_changed.is_connected(_on_combat_state_changed):
		_combat_state.state_changed.connect(_on_combat_state_changed)


func _physics_process(delta: float) -> void:
	var input_requested: bool = InputMap.has_action(&"ward") and Input.is_action_pressed(&"ward")
	advance(delta, _guard_requested or input_requested)


func advance(delta: float, guard_requested: bool) -> void:
	if not _enabled or not _is_configured():
		_set_active(false)
		return
	if not guard_requested or not _combat_state.can_guard():
		_set_active(false)
		return
	if not is_active:
		if _mana.current_mana <= 0.0:
			return
		if not _stamina.try_spend(activation_stamina_cost):
			return
		_set_active(true)
	if delta <= 0.0:
		return
	var has_stamina: bool = _stamina.spend_continuous(stamina_per_second, delta)
	var has_mana: bool = _mana.spend_continuous(mana_per_second, delta)
	if not has_stamina or not has_mana:
		_break_ward()


func filter_damage(incoming_damage: float) -> float:
	if not is_active or incoming_damage <= 0.0:
		return incoming_damage
	var block_cost: float = incoming_damage * stamina_per_blocked_damage
	if not _stamina.try_spend(block_cost):
		_break_ward()
		return incoming_damage
	var received_damage: float = incoming_damage * (1.0 - damage_reduction)
	damage_blocked.emit(incoming_damage, received_damage)
	return received_damage


func set_guard_requested(requested: bool) -> void:
	_guard_requested = requested


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		_guard_requested = false
		_set_active(false)


func reset() -> void:
	_guard_requested = false
	_enabled = true
	_set_active(false)


func _is_configured() -> bool:
	return is_instance_valid(_stamina) and is_instance_valid(_mana) \
		and is_instance_valid(_combat_state)


func _break_ward() -> void:
	if not is_active:
		return
	_set_active(false)
	ward_broken.emit()


func _set_active(active: bool) -> void:
	if is_active == active:
		return
	is_active = active
	active_changed.emit(is_active)


func _on_combat_state_changed(
	_previous_state: CombatStateComponent.State,
	_next_state: CombatStateComponent.State
) -> void:
	if not _combat_state.can_guard():
		_set_active(false)
