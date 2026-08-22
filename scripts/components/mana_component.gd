class_name ManaComponent
extends Node

signal mana_changed(current: float, maximum: float)
signal mana_spent(amount: float)
signal spend_failed(required: float, available: float)

@export_range(1.0, 10000.0, 1.0) var max_mana: float = 100.0
@export_range(0.0, 1000.0, 0.5) var regeneration_per_second: float = 12.0

var current_mana: float = 0.0


func _ready() -> void:
	reset()
	set_process(false)


func _process(delta: float) -> void:
	if current_mana >= max_mana:
		return

	var previous_mana: float = current_mana
	current_mana = minf(current_mana + regeneration_per_second * delta, max_mana)
	if not is_equal_approx(previous_mana, current_mana):
		mana_changed.emit(current_mana, max_mana)
	if current_mana >= max_mana:
		set_process(false)


func try_spend(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if current_mana + 0.001 < amount:
		spend_failed.emit(amount, current_mana)
		return false

	current_mana -= amount
	set_process(regeneration_per_second > 0.0)
	mana_spent.emit(amount)
	mana_changed.emit(current_mana, max_mana)
	return true


func spend_continuous(amount_per_second: float, delta: float) -> bool:
	if amount_per_second <= 0.0 or delta <= 0.0:
		return current_mana > 0.0
	if current_mana <= 0.0:
		spend_failed.emit(amount_per_second * delta, current_mana)
		return false
	var amount: float = minf(current_mana, amount_per_second * delta)
	current_mana -= amount
	set_process(regeneration_per_second > 0.0)
	mana_spent.emit(amount)
	mana_changed.emit(current_mana, max_mana)
	return current_mana > 0.0


func restore(amount: float) -> bool:
	if amount <= 0.0 or current_mana >= max_mana:
		return false

	current_mana = minf(current_mana + amount, max_mana)
	mana_changed.emit(current_mana, max_mana)
	set_process(regeneration_per_second > 0.0 and current_mana < max_mana)
	return true


func reset() -> void:
	current_mana = max_mana
	set_process(false)
	mana_changed.emit(current_mana, max_mana)


func get_mana_ratio() -> float:
	return current_mana / max_mana if max_mana > 0.0 else 0.0


func set_max_mana(value: float, fill_added_capacity: bool = false) -> void:
	var previous_maximum: float = max_mana
	max_mana = maxf(1.0, value)
	if fill_added_capacity and max_mana > previous_maximum:
		current_mana += max_mana - previous_maximum
	current_mana = minf(current_mana, max_mana)
	mana_changed.emit(current_mana, max_mana)
	set_process(regeneration_per_second > 0.0 and current_mana < max_mana)
