class_name MagePlayer
extends CharacterBody3D

signal defeated()
signal respawned()

@export_range(0.5, 10.0, 0.1) var respawn_delay: float = 2.0

var _spawn_transform: Transform3D
var _original_collision_layer: int
var _hit_tween: Tween
var _cast_sound: AudioStreamWAV
var _hurt_sound: AudioStreamWAV
var _death_sound: AudioStreamWAV

@onready var _controller: PlayerController = get_node("PlayerController") as PlayerController
@onready var _health: HealthComponent = get_node("HealthComponent") as HealthComponent
@onready var _mana: ManaComponent = get_node("ManaComponent") as ManaComponent
@onready var _hurtbox: HurtboxComponent = get_node("HurtboxComponent") as HurtboxComponent
@onready var _spell_caster: SpellCaster = get_node("SpellCaster") as SpellCaster
@onready var _spell_loadout: SpellLoadout = get_node("SpellLoadout") as SpellLoadout
@onready var _cast_origin: Marker3D = get_node("CastOrigin") as Marker3D
@onready var _visuals: Node3D = get_node("Visuals") as Node3D
@onready var _respawn_timer: Timer = get_node("RespawnTimer") as Timer
@onready var _sfx_pool: SfxPool3D = get_node("SfxPool3D") as SfxPool3D


func _ready() -> void:
	_spawn_transform = global_transform
	_original_collision_layer = collision_layer
	_controller.bind(self, _visuals)
	_hurtbox.bind_health(_health)
	var spawn_parent: Node = get_tree().current_scene
	if not is_instance_valid(spawn_parent):
		spawn_parent = get_parent()
	_spell_caster.bind(self, _cast_origin, _mana, spawn_parent, &"player")
	_spell_loadout.bind(_spell_caster)
	_cast_sound = SyntheticAudio.create_spell_cast()
	_hurt_sound = SyntheticAudio.create_hurt()
	_death_sound = SyntheticAudio.create_death()
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	_spell_caster.spell_cast.connect(_on_spell_cast)
	_respawn_timer.timeout.connect(_on_respawn_timeout)


func get_health_component() -> HealthComponent:
	return _health


func get_mana_component() -> ManaComponent:
	return _mana


func get_hurtbox_component() -> HurtboxComponent:
	return _hurtbox


func get_spell_caster() -> SpellCaster:
	return _spell_caster


func get_spell_loadout() -> SpellLoadout:
	return _spell_loadout


func _on_spell_cast(_spell: SpellData) -> void:
	_sfx_pool.play_sfx(_cast_sound, -2.0)


func _on_damaged(_amount: float) -> void:
	_sfx_pool.play_sfx(_hurt_sound)
	if _hit_tween != null:
		_hit_tween.kill()
	_visuals.scale = Vector3(1.12, 0.88, 1.12)
	_hit_tween = create_tween()
	_hit_tween.set_trans(Tween.TRANS_BACK)
	_hit_tween.set_ease(Tween.EASE_OUT)
	_hit_tween.tween_property(_visuals, "scale", Vector3.ONE, 0.16)


func _on_died() -> void:
	_sfx_pool.play_sfx(_death_sound, -1.0)
	_controller.set_enabled(false)
	_spell_caster.set_enabled(false)
	_spell_loadout.set_enabled(false)
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
	_visuals.scale = Vector3.ONE
	_visuals.visible = true
	collision_layer = _original_collision_layer
	_hurtbox.set_deferred("monitoring", true)
	_hurtbox.set_deferred("monitorable", true)
	_controller.set_enabled(true)
	_spell_caster.set_enabled(true)
	_spell_loadout.set_enabled(true)
	respawned.emit()
