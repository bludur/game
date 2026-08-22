class_name HealthComponent
extends Node

signal health_changed(current: float, maximum: float)
signal damaged(amount: float)
signal healed(amount: float)
signal died()

@export_range(1.0, 10000.0, 1.0) var max_health: float = 100.0

var current_health: float = 0.0


func _ready() -> void:
	reset()


func take_damage(amount: float) -> bool:
	if amount <= 0.0 or not is_alive():
		return false

	var applied_damage: float = minf(amount, current_health)
	current_health -= applied_damage
	damaged.emit(applied_damage)
	health_changed.emit(current_health, max_health)

	if is_zero_approx(current_health):
		died.emit()
	return true


func heal(amount: float) -> bool:
	if amount <= 0.0 or not is_alive() or is_equal_approx(current_health, max_health):
		return false

	var previous_health: float = current_health
	current_health = minf(current_health + amount, max_health)
	healed.emit(current_health - previous_health)
	health_changed.emit(current_health, max_health)
	return true


func reset() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func is_alive() -> bool:
	return current_health > 0.0


func get_health_ratio() -> float:
	return current_health / max_health if max_health > 0.0 else 0.0


func set_max_health(value: float, fill_added_capacity: bool = false) -> void:
	var previous_maximum: float = max_health
	max_health = maxf(1.0, value)
	if fill_added_capacity and max_health > previous_maximum:
		current_health += max_health - previous_maximum
	current_health = minf(current_health, max_health)
	health_changed.emit(current_health, max_health)
