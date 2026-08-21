class_name TrainingTarget
extends StaticBody3D

@export_range(0.5, 10.0, 0.1) var respawn_delay: float = 2.5
@export_range(-180.0, 180.0, 1.0) var rotation_speed_degrees: float = 28.0

var _original_collision_layer: int
var _pulse_tween: Tween

@onready var _visuals: Node3D = get_node("Visuals") as Node3D
@onready var _health: HealthComponent = get_node("HealthComponent") as HealthComponent
@onready var _hurtbox: HurtboxComponent = get_node("HurtboxComponent") as HurtboxComponent
@onready var _health_label: Label3D = get_node("HealthLabel") as Label3D
@onready var _respawn_timer: Timer = get_node("RespawnTimer") as Timer


func _ready() -> void:
	_original_collision_layer = collision_layer
	_hurtbox.bind_health(_health)
	_health.health_changed.connect(_on_health_changed)
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	_respawn_timer.timeout.connect(_on_respawned)
	_on_health_changed(_health.current_health, _health.max_health)


func _process(delta: float) -> void:
	_visuals.rotate_y(deg_to_rad(rotation_speed_degrees) * delta)


func get_health_component() -> HealthComponent:
	return _health


func _on_health_changed(current: float, maximum: float) -> void:
	_health_label.text = "%d / %d" % [ceili(current), ceili(maximum)]


func _on_damaged(_amount: float) -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
	_visuals.scale = Vector3.ONE * 1.16
	_pulse_tween = create_tween()
	_pulse_tween.set_ease(Tween.EASE_OUT)
	_pulse_tween.set_trans(Tween.TRANS_BACK)
	_pulse_tween.tween_property(_visuals, "scale", Vector3.ONE, 0.18)


func _on_died() -> void:
	set_process(false)
	_visuals.visible = false
	_health_label.text = "DESTROYED"
	collision_layer = 0
	_hurtbox.set_deferred("monitoring", false)
	_hurtbox.set_deferred("monitorable", false)
	_respawn_timer.start(respawn_delay)


func _on_respawned() -> void:
	_health.reset()
	_visuals.scale = Vector3.ONE
	_visuals.visible = true
	collision_layer = _original_collision_layer
	_hurtbox.set_deferred("monitoring", true)
	_hurtbox.set_deferred("monitorable", true)
	set_process(true)
