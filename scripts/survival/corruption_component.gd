class_name CorruptionComponent
extends Node

signal corruption_changed(current: float, maximum: float, reason: StringName)
signal threshold_changed(threshold: int)

@export_range(1.0, 500.0, 1.0) var maximum_corruption: float = 100.0
@export_range(0.0, 30.0, 0.1) var night_gain_per_second: float = 0.55
@export_range(0.0, 30.0, 0.1) var cursed_gain_per_second: float = 1.1
@export_range(0.0, 30.0, 0.1) var ward_cleanse_per_second: float = 0.8
@export_range(0.0, 0.95, 0.05) var base_resistance: float = 0.0

var current_corruption: float = 0.0
var _temporary_resistance: float = 0.0
var _resistance_remaining: float = 0.0
var _threshold: int = 0
var _external_resistance_provider: Callable


func update_exposure(delta: float, is_night: bool, in_ward: bool, in_cursed_zone: bool) -> void:
	if _resistance_remaining > 0.0:
		_resistance_remaining = maxf(0.0, _resistance_remaining - delta)
		if _resistance_remaining <= 0.0:
			_temporary_resistance = 0.0
	if in_ward:
		cleanse(ward_cleanse_per_second * delta, &"witchfire")
		return
	var gain: float = 0.0
	var reason: StringName = &"safe"
	if is_night:
		gain += night_gain_per_second
		reason = &"night"
	if in_cursed_zone:
		gain += cursed_gain_per_second
		reason = &"cursed_ground"
	if gain > 0.0:
		add_corruption(gain * delta, reason)


func add_corruption(amount: float, reason: StringName) -> bool:
	if amount <= 0.0 or current_corruption >= maximum_corruption:
		return false
	var external_resistance: float = 0.0
	if _external_resistance_provider.is_valid():
		external_resistance = float(_external_resistance_provider.call())
	var resistance: float = clampf(
		base_resistance + _temporary_resistance + external_resistance,
		0.0,
		0.9
	)
	var previous: float = current_corruption
	current_corruption = minf(maximum_corruption, current_corruption + amount * (1.0 - resistance))
	if not is_equal_approx(previous, current_corruption):
		corruption_changed.emit(current_corruption, maximum_corruption, reason)
		_update_threshold()
	return true


func cleanse(amount: float, reason: StringName = &"cleansed") -> bool:
	if amount <= 0.0 or current_corruption <= 0.0:
		return false
	var previous: float = current_corruption
	current_corruption = maxf(0.0, current_corruption - amount)
	if not is_equal_approx(previous, current_corruption):
		corruption_changed.emit(current_corruption, maximum_corruption, reason)
		_update_threshold()
	return true


func apply_temporary_resistance(amount: float, duration: float) -> void:
	_temporary_resistance = clampf(amount, 0.0, 0.9)
	_resistance_remaining = maxf(0.0, duration)


func set_external_resistance_provider(provider: Callable) -> void:
	_external_resistance_provider = provider


func get_threshold() -> int:
	return _threshold


func get_enemy_detection_multiplier() -> float:
	return 1.0 + float(_threshold) * 0.2


func get_regeneration_multiplier() -> float:
	return 0.65 if _threshold >= 2 else 1.0


func serialize_state() -> Dictionary:
	return {
		"current": current_corruption,
		"temporary_resistance": _temporary_resistance,
		"resistance_remaining": _resistance_remaining,
	}


func apply_state(state: Dictionary) -> void:
	current_corruption = clampf(float(state.get("current", 0.0)), 0.0, maximum_corruption)
	_temporary_resistance = clampf(float(state.get("temporary_resistance", 0.0)), 0.0, 0.9)
	_resistance_remaining = maxf(0.0, float(state.get("resistance_remaining", 0.0)))
	_update_threshold()
	corruption_changed.emit(current_corruption, maximum_corruption, &"loaded")


func _update_threshold() -> void:
	var next_threshold: int = 0
	if current_corruption >= 75.0:
		next_threshold = 3
	elif current_corruption >= 50.0:
		next_threshold = 2
	elif current_corruption >= 25.0:
		next_threshold = 1
	if next_threshold != _threshold:
		_threshold = next_threshold
		threshold_changed.emit(_threshold)
