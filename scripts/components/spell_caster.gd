class_name SpellCaster
extends Node

signal spell_cast(spell: SpellData)
signal cast_failed(reason: StringName)
signal cooldown_changed(remaining: float, total: float)

const FAILURE_NOT_CONFIGURED: StringName = &"not_configured"
const FAILURE_COOLDOWN: StringName = &"cooldown"
const FAILURE_MANA: StringName = &"mana"
const FAILURE_INVALID_TARGET: StringName = &"invalid_target"
const FAILURE_DISABLED: StringName = &"disabled"

@export var spell_data: SpellData

var caster_body: Node3D
var cast_origin: Marker3D
var mana_component: ManaComponent
var projectile_parent: Node
var caster_faction: StringName = &"neutral"
var _enabled: bool = true

@onready var _cooldown_timer: Timer = get_node("CooldownTimer") as Timer


func _ready() -> void:
	_cooldown_timer.timeout.connect(_on_cooldown_finished)
	set_process(false)


func bind(
	body: Node3D,
	origin: Marker3D,
	mana: ManaComponent,
	spawn_parent: Node = null,
	faction: StringName = &"neutral"
) -> void:
	caster_body = body
	cast_origin = origin
	mana_component = mana
	projectile_parent = spawn_parent
	caster_faction = faction


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	set_process_unhandled_input(enabled)
	if enabled:
		return
	_cooldown_timer.stop()
	set_process(false)
	cooldown_changed.emit(0.0, _cooldown_timer.wait_time)


func set_spell(spell: SpellData) -> bool:
	if spell == null or not spell.is_valid_definition():
		return false
	spell_data = spell
	cooldown_changed.emit(_cooldown_timer.time_left, spell_data.cooldown_seconds)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not _enabled or not event.is_action_pressed(&"primary_spell"):
		return

	var target_position: Variant
	if event is InputEventJoypadButton:
		target_position = _get_gamepad_target_position()
	else:
		target_position = _get_mouse_ground_position(get_viewport().get_mouse_position())
	if target_position is Vector3:
		cast_at(target_position as Vector3)
	else:
		cast_failed.emit(FAILURE_INVALID_TARGET)
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	cooldown_changed.emit(_cooldown_timer.time_left, _cooldown_timer.wait_time)


func cast_at(target_position: Vector3) -> bool:
	if not _enabled:
		cast_failed.emit(FAILURE_DISABLED)
		return false
	if not _is_configured():
		cast_failed.emit(FAILURE_NOT_CONFIGURED)
		return false
	if not _cooldown_timer.is_stopped():
		cast_failed.emit(FAILURE_COOLDOWN)
		return false

	var direction: Vector3 = target_position - cast_origin.global_position
	direction.y = 0.0
	if spell_data.targeting_type == SpellData.TargetingType.PROJECTILE \
			and direction.length_squared() < 0.001:
		cast_failed.emit(FAILURE_INVALID_TARGET)
		return false
	var resolved_target: Vector3 = target_position
	if direction.length() > spell_data.range_meters:
		resolved_target = cast_origin.global_position + direction.normalized() * spell_data.range_meters
	resolved_target.y = 0.05
	if not mana_component.try_spend(spell_data.mana_cost):
		cast_failed.emit(FAILURE_MANA)
		return false

	var effect_node: Node = spell_data.projectile_scene.instantiate()

	var spawn_parent: Node = projectile_parent
	if not is_instance_valid(spawn_parent):
		spawn_parent = get_tree().current_scene
	if not is_instance_valid(spawn_parent):
		mana_component.restore(spell_data.mana_cost)
		effect_node.queue_free()
		cast_failed.emit(FAILURE_NOT_CONFIGURED)
		return false
	spawn_parent.add_child(effect_node)
	match spell_data.targeting_type:
		SpellData.TargetingType.PROJECTILE:
			if effect_node is not ArcaneBolt:
				_refund_invalid_effect(effect_node)
				return false
			var projectile: ArcaneBolt = effect_node as ArcaneBolt
			projectile.global_position = cast_origin.global_position
			projectile.configure(direction.normalized(), spell_data, caster_body, caster_faction)
		SpellData.TargetingType.AREA:
			if effect_node is not FrostCircle:
				_refund_invalid_effect(effect_node)
				return false
			var area_effect: FrostCircle = effect_node as FrostCircle
			area_effect.global_position = resolved_target
			area_effect.configure(spell_data, caster_faction)
		SpellData.TargetingType.CHAIN:
			if effect_node is not ChainLightning:
				_refund_invalid_effect(effect_node)
				return false
			var chain_effect: ChainLightning = effect_node as ChainLightning
			chain_effect.global_position = cast_origin.global_position
			if not chain_effect.configure(spell_data, caster_faction, caster_body, resolved_target):
				mana_component.restore(spell_data.mana_cost)
				chain_effect.queue_free()
				cast_failed.emit(FAILURE_INVALID_TARGET)
				return false
		_:
			_refund_invalid_effect(effect_node)
			return false

	_cooldown_timer.start(spell_data.cooldown_seconds)
	set_process(true)
	cooldown_changed.emit(_cooldown_timer.time_left, _cooldown_timer.wait_time)
	spell_cast.emit(spell_data)
	return true


func get_cooldown_remaining() -> float:
	return _cooldown_timer.time_left


func _get_mouse_ground_position(screen_position: Vector2) -> Variant:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or not is_instance_valid(cast_origin):
		return null

	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_position)
	var casting_plane: Plane = Plane(Vector3.UP, cast_origin.global_position.y)
	return casting_plane.intersects_ray(ray_origin, ray_direction)


func _get_gamepad_target_position() -> Vector3:
	var aim: Vector2 = Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down")
	var direction: Vector3
	if aim.length_squared() > 0.12:
		direction = Vector3(aim.x, 0.0, aim.y).normalized()
	else:
		direction = -caster_body.global_basis.z
		direction.y = 0.0
		direction = direction.normalized()
	return cast_origin.global_position + direction * spell_data.range_meters


func _is_configured() -> bool:
	return spell_data != null \
		and spell_data.is_valid_definition() \
		and spell_data.projectile_scene != null \
		and is_instance_valid(caster_body) \
		and is_instance_valid(cast_origin) \
		and is_instance_valid(mana_component)


func _refund_invalid_effect(effect_node: Node) -> void:
	mana_component.restore(spell_data.mana_cost)
	effect_node.queue_free()
	cast_failed.emit(FAILURE_NOT_CONFIGURED)


func _on_cooldown_finished() -> void:
	set_process(false)
	cooldown_changed.emit(0.0, _cooldown_timer.wait_time)
