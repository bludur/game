class_name WorldClock
extends Node

signal time_changed(normalized_time: float, day_number: int)
signal phase_changed(phase: Phase)

enum Phase {
	DAWN,
	DAY,
	DUSK,
	NIGHT,
}

@export_range(60.0, 3600.0, 10.0) var day_duration_seconds: float = 720.0
@export_range(0.0, 1.0, 0.01) var starting_time: float = 0.28

var normalized_time: float = 0.28
var day_number: int = 1
var current_phase: Phase = Phase.DAY
var _emit_accumulator: float = 0.0


func _ready() -> void:
	normalized_time = starting_time
	current_phase = _phase_for_time(normalized_time)
	time_changed.emit(normalized_time, day_number)
	phase_changed.emit(current_phase)


func _process(delta: float) -> void:
	var previous_phase: Phase = current_phase
	normalized_time += delta / day_duration_seconds
	if normalized_time >= 1.0:
		normalized_time = fmod(normalized_time, 1.0)
		day_number += 1
	current_phase = _phase_for_time(normalized_time)
	if current_phase != previous_phase:
		phase_changed.emit(current_phase)
	_emit_accumulator += delta
	if _emit_accumulator >= 0.2:
		_emit_accumulator = 0.0
		time_changed.emit(normalized_time, day_number)


func is_night() -> bool:
	return current_phase == Phase.NIGHT


func get_time_label() -> String:
	var total_minutes: int = floori(normalized_time * 1440.0)
	return "%02d:%02d" % [total_minutes / 60, total_minutes % 60]


func serialize_state() -> Dictionary:
	return {"normalized_time": normalized_time, "day_number": day_number}


func apply_state(state: Dictionary) -> void:
	normalized_time = clampf(float(state.get("normalized_time", starting_time)), 0.0, 0.9999)
	day_number = maxi(1, int(state.get("day_number", 1)))
	current_phase = _phase_for_time(normalized_time)
	time_changed.emit(normalized_time, day_number)
	phase_changed.emit(current_phase)


func _phase_for_time(time: float) -> Phase:
	if time < 0.22:
		return Phase.NIGHT
	if time < 0.30:
		return Phase.DAWN
	if time < 0.72:
		return Phase.DAY
	if time < 0.80:
		return Phase.DUSK
	return Phase.NIGHT
