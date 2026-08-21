class_name MagePlayer
extends CharacterBody3D

signal defeated()
signal respawned()

@export_range(0.5, 10.0, 0.1) var respawn_delay: float = 2.0

var _spawn_transform: Transform3D
var _original_collision_layer: int

@onready var _controller: PlayerController = get_node("PlayerController") as PlayerController
@onready var _health: HealthComponent = get_node("HealthComponent") as HealthComponent
@onready var _mana: ManaComponent = get_node("ManaComponent") as ManaComponent
@onready var _hurtbox: HurtboxComponent = get_node("HurtboxComponent") as HurtboxComponent
@onready var _spell_caster: SpellCaster = get_node("SpellCaster") as SpellCaster
@onready var _cast_origin: Marker3D = get_node("CastOrigin") as Marker3D
@onready var _visuals: Node3D = get_node("Visuals") as Node3D
@onready var _respawn_timer: Timer = get_node("RespawnTimer") as Timer


func _ready() -> void:
	_spawn_transform = global_transform
	_original_collision_layer = collision_layer
	_controller.bind(self, _visuals)
	_hurtbox.bind_health(_health)
	var spawn_parent: Node = get_tree().current_scene
	if not is_instance_valid(spawn_parent):
		spawn_parent = get_parent()
	_spell_caster.bind(self, _cast_origin, _mana, spawn_parent, &"player")
	_health.died.connect(_on_died)
	_respawn_timer.timeout.connect(_on_respawn_timeout)


func get_health_component() -> HealthComponent:
	return _health


func get_mana_component() -> ManaComponent:
	return _mana


func get_hurtbox_component() -> HurtboxComponent:
	return _hurtbox


func get_spell_caster() -> SpellCaster:
	return _spell_caster


func _on_died() -> void:
	_controller.set_enabled(false)
	_spell_caster.set_enabled(false)
	velocity = Vector3.ZERO
	_visuals.visible = false
	collision_layer = 0
	_hurtbox.set_deferred("monitoring", false)
	_hurtbox.set_deferred("monitorable", false)
	_respawn_timer.start(respawn_delay)
	defeated.emit()


func _on_respawn_timeout() -> void:
	global_transform = _spawn_transform
	reset_physics_interpolation()
	_health.reset()
	_mana.reset()
	_visuals.visible = true
	collision_layer = _original_collision_layer
	_hurtbox.set_deferred("monitoring", true)
	_hurtbox.set_deferred("monitorable", true)
	_controller.set_enabled(true)
	_spell_caster.set_enabled(true)
	respawned.emit()
