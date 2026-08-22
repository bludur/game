class_name MagePlayer
extends CharacterBody3D

signal defeated()
signal respawned()

@export_range(0.5, 10.0, 0.1) var respawn_delay: float = 2.0
@export var auto_respawn: bool = true

var _spawn_transform: Transform3D
var _original_collision_layer: int
var _hit_tween: Tween
var _cast_sound: AudioStreamWAV
var _hurt_sound: AudioStreamWAV
var _death_sound: AudioStreamWAV
var _dash_sound: AudioStreamWAV
var _ward_sound: AudioStreamWAV

@onready var _controller: PlayerController = get_node("PlayerController") as PlayerController
@onready var _health: HealthComponent = get_node("HealthComponent") as HealthComponent
@onready var _mana: ManaComponent = get_node("ManaComponent") as ManaComponent
@onready var _stamina: StaminaComponent = get_node("StaminaComponent") as StaminaComponent
@onready var _combat_state: CombatStateComponent = get_node("CombatStateComponent") as CombatStateComponent
@onready var _ward: WardComponent = get_node("WardComponent") as WardComponent
@onready var _hurtbox: HurtboxComponent = get_node("HurtboxComponent") as HurtboxComponent
@onready var _spell_caster: SpellCaster = get_node("SpellCaster") as SpellCaster
@onready var _spell_loadout: SpellLoadout = get_node("SpellLoadout") as SpellLoadout
@onready var _dash: DashComponent = get_node("DashComponent") as DashComponent
@onready var _inventory: InventoryComponent = get_node("InventoryComponent") as InventoryComponent
@onready var _corruption: CorruptionComponent = get_node("CorruptionComponent") as CorruptionComponent
@onready var _cast_origin: Marker3D = get_node("CastOrigin") as Marker3D
@onready var _visuals: Node3D = get_node("Visuals") as Node3D
@onready var _respawn_timer: Timer = get_node("RespawnTimer") as Timer
@onready var _sfx_pool: SfxPool3D = get_node("SfxPool3D") as SfxPool3D
@onready var _dash_trail: GPUParticles3D = get_node("DashTrail") as GPUParticles3D
@onready var _animator: CharacterAnimator = get_node("CharacterAnimator") as CharacterAnimator
@onready var _chain_range_preview: MeshInstance3D = get_node("ChainRangePreview") as MeshInstance3D
@onready var _ward_bubble: MeshInstance3D = get_node("WardVisuals/WardBubble") as MeshInstance3D
@onready var _ward_particles: GPUParticles3D = get_node("WardVisuals/WardParticles") as GPUParticles3D
@onready var _ward_glow: OmniLight3D = get_node("WardVisuals/WardGlow") as OmniLight3D


func _ready() -> void:
	_spawn_transform = global_transform
	_original_collision_layer = collision_layer
	_controller.bind(self, _visuals, _dash, _stamina, _combat_state)
	_hurtbox.bind_health(_health)
	_hurtbox.set_damage_filter(_ward.filter_damage)
	_ward.bind(_stamina, _mana, _combat_state)
	var spawn_parent: Node = get_tree().current_scene
	if not is_instance_valid(spawn_parent):
		spawn_parent = get_parent()
	_spell_caster.bind(self, _cast_origin, _mana, spawn_parent, &"player", _combat_state)
	_spell_loadout.bind(_spell_caster)
	_spell_loadout.active_spell_changed.connect(_on_active_spell_changed)
	_on_active_spell_changed(_spell_loadout.get_active_spell(), _spell_loadout.active_slot_index)
	_cast_sound = SyntheticAudio.create_spell_cast()
	_hurt_sound = SyntheticAudio.create_hurt()
	_death_sound = SyntheticAudio.create_death()
	_dash_sound = SyntheticAudio.create_dash()
	_ward_sound = SyntheticAudio.create_ward()
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	_spell_caster.spell_cast.connect(_on_spell_cast)
	_spell_caster.cast_direction_resolved.connect(_on_cast_direction_resolved)
	_dash.dash_started.connect(_on_dash_started)
	_dash.dash_finished.connect(_on_dash_finished)
	_ward.active_changed.connect(_on_ward_active_changed)
	_controller.locomotion_changed.connect(_animator.set_locomotion)
	_respawn_timer.timeout.connect(_on_respawn_timeout)


func get_health_component() -> HealthComponent:
	return _health


func get_mana_component() -> ManaComponent:
	return _mana


func get_stamina_component() -> StaminaComponent:
	return _stamina


func get_combat_state_component() -> CombatStateComponent:
	return _combat_state


func get_ward_component() -> WardComponent:
	return _ward


func get_hurtbox_component() -> HurtboxComponent:
	return _hurtbox


func get_spell_caster() -> SpellCaster:
	return _spell_caster


func get_spell_loadout() -> SpellLoadout:
	return _spell_loadout


func get_dash_component() -> DashComponent:
	return _dash


func get_inventory_component() -> InventoryComponent:
	return _inventory


func get_corruption_component() -> CorruptionComponent:
	return _corruption


func set_respawn_transform(next_transform: Transform3D) -> void:
	_spawn_transform = next_transform


func respawn_at(next_transform: Transform3D) -> void:
	_spawn_transform = next_transform
	_restore_player()
	respawned.emit()


func request_dash(direction: Vector3 = Vector3.ZERO) -> bool:
	return _controller.request_dash(direction)


func set_controls_enabled(enabled: bool) -> void:
	_controller.set_enabled(enabled)
	_spell_caster.set_enabled(enabled)
	_spell_loadout.set_enabled(enabled)
	_dash.set_enabled(enabled)
	_combat_state.set_enabled(enabled)
	_ward.set_enabled(enabled)
	_update_range_preview(enabled)


func set_auto_respawn(enabled: bool) -> void:
	auto_respawn = enabled
	if not enabled:
		_respawn_timer.stop()


func reset_for_new_run() -> void:
	_respawn_timer.stop()
	_restore_player()


func _on_spell_cast(_spell: SpellData) -> void:
	_sfx_pool.play_sfx(_cast_sound, -2.0)
	_animator.play_cast()


func _on_cast_direction_resolved(direction: Vector3) -> void:
	_controller.set_facing_direction(direction)


func _on_active_spell_changed(_spell: SpellData, _slot_index: int) -> void:
	_update_range_preview(true)


func _update_range_preview(controls_enabled: bool) -> void:
	var active_spell: SpellData = _spell_loadout.get_active_spell()
	var is_chain: bool = active_spell != null \
		and active_spell.targeting_type == SpellData.TargetingType.CHAIN
	_chain_range_preview.visible = controls_enabled and is_chain
	if is_chain:
		_chain_range_preview.scale = Vector3.ONE * active_spell.range_meters


func _on_damaged(_amount: float) -> void:
	_combat_state.begin_stagger()
	_sfx_pool.play_sfx(_hurt_sound)
	_animator.play_hit()
	if _hit_tween != null:
		_hit_tween.kill()
	_visuals.scale = Vector3(1.12, 0.88, 1.12)
	_hit_tween = create_tween()
	_hit_tween.set_trans(Tween.TRANS_BACK)
	_hit_tween.set_ease(Tween.EASE_OUT)
	_hit_tween.tween_property(_visuals, "scale", Vector3.ONE, 0.16)


func _on_dash_started(_direction: Vector3) -> void:
	_combat_state.try_begin_dodge(_dash.dash_duration)
	_hurtbox.grant_invulnerability(_dash.dash_duration + 0.05)
	_dash_trail.restart()
	_dash_trail.emitting = true
	_sfx_pool.play_sfx(_dash_sound, -2.0)
	_animator.play_dash()


func _on_dash_finished() -> void:
	_dash_trail.emitting = false


func _on_ward_active_changed(active: bool) -> void:
	_ward_bubble.visible = active
	_ward_glow.visible = active
	_ward_particles.emitting = active
	if active:
		_ward_particles.restart()
		_sfx_pool.play_sfx(_ward_sound, -4.0)


func _on_died() -> void:
	_sfx_pool.play_sfx(_death_sound, -1.0)
	set_controls_enabled(false)
	velocity = Vector3.ZERO
	_animator.play_death()
	collision_layer = 0
	_hurtbox.set_deferred("monitoring", false)
	_hurtbox.set_deferred("monitorable", false)
	if auto_respawn:
		_respawn_timer.start(respawn_delay)
	defeated.emit()


func _on_respawn_timeout() -> void:
	_restore_player()
	respawned.emit()


func _restore_player() -> void:
	global_transform = _spawn_transform
	reset_physics_interpolation()
	_health.reset()
	_mana.reset()
	_stamina.reset()
	_combat_state.reset()
	_ward.reset()
	_hurtbox.clear_invulnerability()
	_visuals.scale = Vector3.ONE
	_visuals.visible = true
	_animator.reset_visual()
	collision_layer = _original_collision_layer
	_hurtbox.set_deferred("monitoring", true)
	_hurtbox.set_deferred("monitorable", true)
	set_controls_enabled(true)
