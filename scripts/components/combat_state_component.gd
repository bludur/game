class_name CombatStateComponent
extends Node

signal state_changed(previous_state: State, next_state: State)

enum State {
	READY,
	CASTING,
	RECOVERY,
	DODGING,
	STAGGERED,
}

@export_range(0.01, 1.0, 0.01) var cast_duration: float = 0.12
@export_range(0.01, 1.5, 0.01) var recovery_duration: float = 0.2
@export_range(0.01, 2.0, 0.01) var stagger_duration: float = 0.32

var current_state: State = State.READY
var _time_remaining: float = 0.0
var _enabled: bool = true


func _physics_process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if not _enabled or delta <= 0.0 or current_state == State.READY:
		return
	_time_remaining = maxf(0.0, _time_remaining - delta)
	if _time_remaining > 0.0:
		return
	if current_state == State.CASTING:
		_transition_to(State.RECOVERY, recovery_duration)
	else:
		_transition_to(State.READY, 0.0)


func try_begin_cast() -> bool:
	if not _enabled or current_state != State.READY:
		return false
	_transition_to(State.CASTING, cast_duration)
	return true


func cancel_cast() -> void:
	if current_state == State.CASTING:
		_transition_to(State.READY, 0.0)


func try_begin_dodge(duration: float) -> bool:
	if not _enabled or current_state == State.DODGING or current_state == State.STAGGERED:
		return false
	_transition_to(State.DODGING, maxf(0.01, duration))
	return true


func begin_stagger(duration: float = -1.0) -> bool:
	if not _enabled or current_state == State.DODGING:
		return false
	var resolved_duration: float = stagger_duration if duration < 0.0 else maxf(0.01, duration)
	_transition_to(State.STAGGERED, resolved_duration)
	return true


func can_cast() -> bool:
	return _enabled and current_state == State.READY


func can_guard() -> bool:
	return _enabled and current_state == State.READY


func can_dodge() -> bool:
	return _enabled and current_state != State.DODGING and current_state != State.STAGGERED


func is_dodging() -> bool:
	return current_state == State.DODGING


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		_transition_to(State.READY, 0.0)


func reset() -> void:
	_enabled = true
	_transition_to(State.READY, 0.0)


func get_state_name() -> StringName:
	return StringName(State.keys()[current_state].to_lower())


func get_time_remaining() -> float:
	return _time_remaining


func _transition_to(next_state: State, duration: float) -> void:
	var previous_state: State = current_state
	current_state = next_state
	_time_remaining = maxf(0.0, duration)
	if previous_state != next_state:
		state_changed.emit(previous_state, next_state)
