class_name RootboundMatriarch
extends ArenaWarden

signal purification_required()
signal purification_completed()

var purification_barrier_active: bool = false
var purified: bool = false


func _ready() -> void:
	super._ready()
	get_health_component().health_changed.connect(_on_matriarch_health_changed)


func start_encounter(target: MagePlayer) -> bool:
	purification_barrier_active = false
	purified = false
	return super.start_encounter(target)


func purify() -> bool:
	if not purification_barrier_active or purified:
		return false
	purified = true
	purification_barrier_active = false
	get_hurtbox_component().clear_invulnerability()
	purification_completed.emit()
	return true


func _on_matriarch_health_changed(current: float, maximum: float) -> void:
	if purified or purification_barrier_active or current <= 0.0 or current > maximum * 0.2:
		return
	purification_barrier_active = true
	get_hurtbox_component().grant_invulnerability(3600.0)
	get_health_component().heal(maximum * 0.08)
	purification_required.emit()
