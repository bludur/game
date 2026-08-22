class_name StaminaComponent
extends Node

signal stamina_changed(current: float, maximum: float)
signal stamina_spent(amount: float)
signal spend_failed(required: float, available: float)
signal exhausted()
signal recovered()

@export_range(1.0, 1000.0, 1.0) var max_stamina: float = 100.0
@export_range(0.0, 200.0, 0.5) var regeneration_per_second: float = 24.0
@export_range(0.0, 5.0, 0.05) var regeneration_delay_seconds: float = 0.75

var current_stamina: float = 0.0
var _regeneration_delay_remaining: float = 0.0
var _was_exhausted: bool = false


func _ready() -> void:
	reset()


func _physics_process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	if _regeneration_delay_remaining > 0.0:
		_regeneration_delay_remaining = maxf(0.0, _regeneration_delay_remaining - delta)
		return
	if current_stamina >= max_stamina or regeneration_per_second <= 0.0:
		return
	var previous_stamina: float = current_stamina
	current_stamina = minf(max_stamina, current_stamina + regeneration_per_second * delta)
	if not is_equal_approx(previous_stamina, current_stamina):
		stamina_changed.emit(current_stamina, max_stamina)
	if _was_exhausted and current_stamina > 0.0:
		_was_exhausted = false
		recovered.emit()


func try_spend(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if current_stamina + 0.001 < amount:
		spend_failed.emit(amount, current_stamina)
		return false
	_apply_spend(amount)
	return true


func spend_continuous(amount_per_second: float, delta: float) -> bool:
	if amount_per_second <= 0.0 or delta <= 0.0:
		return current_stamina > 0.0
	if current_stamina <= 0.0:
		spend_failed.emit(amount_per_second * delta, current_stamina)
		return false
	_apply_spend(minf(current_stamina, amount_per_second * delta))
	return current_stamina > 0.0


func restore(amount: float) -> bool:
	if amount <= 0.0 or current_stamina >= max_stamina:
		return false
	var was_empty: bool = current_stamina <= 0.0
	current_stamina = minf(max_stamina, current_stamina + amount)
	stamina_changed.emit(current_stamina, max_stamina)
	if was_empty and current_stamina > 0.0:
		_was_exhausted = false
		recovered.emit()
	return true


func reset() -> void:
	current_stamina = max_stamina
	_regeneration_delay_remaining = 0.0
	_was_exhausted = false
	stamina_changed.emit(current_stamina, max_stamina)


func get_stamina_ratio() -> float:
	return current_stamina / max_stamina if max_stamina > 0.0 else 0.0


func get_regeneration_delay_remaining() -> float:
	return _regeneration_delay_remaining


func _apply_spend(amount: float) -> void:
	current_stamina = maxf(0.0, current_stamina - amount)
	_regeneration_delay_remaining = regeneration_delay_seconds
	stamina_spent.emit(amount)
	stamina_changed.emit(current_stamina, max_stamina)
	if current_stamina <= 0.0 and not _was_exhausted:
		_was_exhausted = true
		exhausted.emit()
