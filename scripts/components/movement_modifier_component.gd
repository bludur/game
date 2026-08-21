class_name MovementModifierComponent
extends Node

signal multiplier_changed(multiplier: float)

var _modifiers: Dictionary[int, float] = {}
var _current_multiplier: float = 1.0


func add_modifier(source_id: int, multiplier: float) -> void:
	_modifiers[source_id] = clampf(multiplier, 0.1, 1.0)
	_recalculate()


func remove_modifier(source_id: int) -> void:
	if not _modifiers.erase(source_id):
		return
	_recalculate()


func clear() -> void:
	if _modifiers.is_empty() and is_equal_approx(_current_multiplier, 1.0):
		return
	_modifiers.clear()
	_current_multiplier = 1.0
	multiplier_changed.emit(_current_multiplier)


func get_multiplier() -> float:
	return _current_multiplier


func _recalculate() -> void:
	var next_multiplier: float = 1.0
	for multiplier: float in _modifiers.values():
		next_multiplier = minf(next_multiplier, multiplier)
	if is_equal_approx(next_multiplier, _current_multiplier):
		return
	_current_multiplier = next_multiplier
	multiplier_changed.emit(_current_multiplier)
