class_name ColdExposureComponent
extends Node

signal exposure_changed(current: float, maximum: float, protected: bool)

@export_range(1.0, 200.0, 1.0) var maximum_exposure: float = 100.0
@export_range(0.1, 20.0, 0.1) var exposure_per_second: float = 4.0
@export_range(0.1, 30.0, 0.1) var recovery_per_second: float = 8.0
@export_range(0.1, 20.0, 0.1) var damage_interval: float = 2.0
@export_range(0.1, 20.0, 0.1) var damage_amount: float = 3.0

var current_exposure: float = 0.0
var _player: MagePlayer
var _damage_remaining: float = 0.0
var _last_display_value: int = -1


func bind(player: MagePlayer) -> void:
	_player = player
	_emit_changed(false)


func advance(delta: float, region_active: bool, in_safe_zone: bool) -> void:
	if delta <= 0.0 or not is_instance_valid(_player):
		return
	var ward_active: bool = _player.get_ward_component().is_active
	var protected: bool = in_safe_zone or ward_active
	if not region_active or in_safe_zone:
		current_exposure = maxf(0.0, current_exposure - recovery_per_second * delta)
	else:
		var resistance: float = _player.get_status_effect_component().get_resistance(
			StatusEffectData.ResistanceType.FROST
		)
		var ward_multiplier: float = 0.25 if ward_active else 1.0
		current_exposure = minf(
			maximum_exposure,
			current_exposure + exposure_per_second * (1.0 - resistance) * ward_multiplier * delta
		)
	if region_active and current_exposure >= maximum_exposure * 0.8 and not protected:
		_damage_remaining -= delta
		if _damage_remaining <= 0.0:
			_player.get_health_component().take_damage(damage_amount)
			_damage_remaining = damage_interval
	else:
		_damage_remaining = 0.0
	var display_value: int = floori(current_exposure)
	if display_value != _last_display_value:
		_emit_changed(protected)


func serialize_state() -> Dictionary:
	return {"exposure": current_exposure}


func apply_state(state: Dictionary) -> void:
	current_exposure = clampf(float(state.get("exposure", 0.0)), 0.0, maximum_exposure)
	_damage_remaining = 0.0
	_emit_changed(false)


func refresh(protected: bool = false) -> void:
	_emit_changed(protected)


func _emit_changed(protected: bool) -> void:
	_last_display_value = floori(current_exposure)
	exposure_changed.emit(current_exposure, maximum_exposure, protected)
