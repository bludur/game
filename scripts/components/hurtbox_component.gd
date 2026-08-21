class_name HurtboxComponent
extends Area3D

signal hit_received(damage: float)

@export_range(0.0, 5.0, 0.05) var invulnerability_seconds: float = 0.0

var health_component: HealthComponent
var _invulnerable: bool = false

@onready var _invulnerability_timer: Timer = get_node("InvulnerabilityTimer") as Timer


func _ready() -> void:
	_invulnerability_timer.timeout.connect(_on_invulnerability_ended)


func bind_health(component: HealthComponent) -> void:
	health_component = component


func receive_hit(damage: float) -> bool:
	if _invulnerable or damage <= 0.0 or not is_instance_valid(health_component):
		return false
	if not health_component.take_damage(damage):
		return false

	hit_received.emit(damage)
	if invulnerability_seconds > 0.0:
		_invulnerable = true
		_invulnerability_timer.start(invulnerability_seconds)
	return true


func _on_invulnerability_ended() -> void:
	_invulnerable = false
