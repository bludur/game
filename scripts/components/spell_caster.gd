class_name SpellCaster
extends Node

signal spell_cast(spell: SpellData)
signal cast_direction_resolved(direction: Vector3)
signal aim_resolved(position: Vector3, surface_normal: Vector3, assisted: bool)
signal cast_failed(reason: StringName)
signal cooldown_changed(remaining: float, total: float)

const FAILURE_NOT_CONFIGURED: StringName = &"not_configured"
const FAILURE_COOLDOWN: StringName = &"cooldown"
const FAILURE_MANA: StringName = &"mana"
const FAILURE_INVALID_TARGET: StringName = &"invalid_target"
const FAILURE_DISABLED: StringName = &"disabled"
const FAILURE_BUSY: StringName = &"busy"

const WORLD_COLLISION_MASK: int = 1
const ENEMY_COLLISION_MASK: int = 4
const HURTBOX_COLLISION_MASK: int = 16

@export var spell_data: SpellData
@export_range(1.0, 15.0, 0.5) var gamepad_assist_cone_degrees: float = 5.5
@export_range(16.0, 512.0, 1.0) var maximum_camera_ray_distance: float = 160.0

var caster_body: Node3D
var cast_origin: Marker3D
var mana_component: ManaComponent
var combat_state: CombatStateComponent
var projectile_parent: Node
var caster_faction: StringName = &"neutral"
var _enabled: bool = true
var _cast_request_pending: bool = false
var _pending_screen_position: Vector2 = Vector2.ZERO
var _pending_gamepad_request: bool = false
var _aim_assist_resolver: AimAssistResolver = AimAssistResolver.new()
var _modifier_provider: Callable

@onready var _cooldown_timer: Timer = get_node("CooldownTimer") as Timer


func _ready() -> void:
	_cooldown_timer.timeout.connect(_on_cooldown_finished)
	set_process(false)
	set_physics_process(false)


func bind(
	body: Node3D,
	origin: Marker3D,
	mana: ManaComponent,
	spawn_parent: Node = null,
	faction: StringName = &"neutral",
	state: CombatStateComponent = null
) -> void:
	caster_body = body
	cast_origin = origin
	mana_component = mana
	projectile_parent = spawn_parent
	caster_faction = faction
	combat_state = state


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	set_process_unhandled_input(enabled)
	if enabled:
		return
	_cast_request_pending = false
	set_physics_process(false)
	_cooldown_timer.stop()
	set_process(false)
	if is_instance_valid(combat_state):
		combat_state.cancel_cast()
	cooldown_changed.emit(0.0, _cooldown_timer.wait_time)


func set_spell(spell: SpellData) -> bool:
	if spell == null or not spell.is_valid_definition():
		return false
	spell_data = spell
	cooldown_changed.emit(_cooldown_timer.time_left, get_effective_cooldown(spell_data))
	return true


func set_modifier_provider(provider: Callable) -> void:
	_modifier_provider = provider


func _unhandled_input(event: InputEvent) -> void:
	if not _enabled or not event.is_action_pressed(&"primary_spell"):
		return
	var screen_position: Vector2 = get_viewport().get_mouse_position()
	var gamepad_request: bool = event is InputEventJoypadButton or event is InputEventJoypadMotion
	if _uses_camera_center_aim() or gamepad_request:
		screen_position = _get_viewport_center()
	request_cast_from_screen(screen_position, gamepad_request)
	get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if not _cast_request_pending:
		set_physics_process(false)
		return
	var screen_position: Vector2 = _pending_screen_position
	var gamepad_request: bool = _pending_gamepad_request
	_cast_request_pending = false
	set_physics_process(false)
	var aim_result: Dictionary = _resolve_camera_aim(screen_position, gamepad_request)
	if aim_result.is_empty():
		cast_failed.emit(FAILURE_INVALID_TARGET)
		return
	var target_position: Vector3 = aim_result[&"position"] as Vector3
	var surface_normal: Vector3 = aim_result[&"normal"] as Vector3
	var assisted: bool = bool(aim_result[&"assisted"])
	aim_resolved.emit(target_position, surface_normal, assisted)
	_cast_at_resolved(target_position, surface_normal)


func _process(_delta: float) -> void:
	cooldown_changed.emit(_cooldown_timer.time_left, _cooldown_timer.wait_time)


func request_cast_from_screen(screen_position: Vector2, gamepad_request: bool = false) -> bool:
	if not _enabled:
		cast_failed.emit(FAILURE_DISABLED)
		return false
	if not _is_configured():
		cast_failed.emit(FAILURE_NOT_CONFIGURED)
		return false
	_cast_request_pending = true
	_pending_screen_position = screen_position
	_pending_gamepad_request = gamepad_request
	set_physics_process(true)
	return true


func cast_at(target_position: Vector3) -> bool:
	return _cast_at_resolved(target_position, Vector3.UP)


func _cast_at_resolved(target_position: Vector3, surface_normal: Vector3) -> bool:
	if not _enabled:
		cast_failed.emit(FAILURE_DISABLED)
		return false
	if not _is_configured():
		cast_failed.emit(FAILURE_NOT_CONFIGURED)
		return false
	if not _cooldown_timer.is_stopped():
		cast_failed.emit(FAILURE_COOLDOWN)
		return false
	if is_instance_valid(combat_state) and not combat_state.try_begin_cast():
		cast_failed.emit(FAILURE_BUSY)
		return false

	var resolved_spell: SpellData = _resolve_runtime_spell()
	var direction: Vector3 = target_position - cast_origin.global_position
	if resolved_spell.targeting_type == SpellData.TargetingType.PROJECTILE \
			and direction.length_squared() < 0.001:
		_cancel_combat_cast()
		cast_failed.emit(FAILURE_INVALID_TARGET)
		return false
	var resolved_target: Vector3 = target_position
	if direction.length() > resolved_spell.range_meters:
		resolved_target = cast_origin.global_position + direction.normalized() * resolved_spell.range_meters
		direction = resolved_target - cast_origin.global_position
	if not mana_component.try_spend(resolved_spell.mana_cost):
		_cancel_combat_cast()
		cast_failed.emit(FAILURE_MANA)
		return false

	var effect_node: Node = resolved_spell.projectile_scene.instantiate()
	var spawn_parent: Node = projectile_parent
	if not is_instance_valid(spawn_parent):
		spawn_parent = get_tree().current_scene
	if not is_instance_valid(spawn_parent):
		mana_component.restore(resolved_spell.mana_cost)
		effect_node.queue_free()
		_cancel_combat_cast()
		cast_failed.emit(FAILURE_NOT_CONFIGURED)
		return false
	spawn_parent.add_child(effect_node)
	match resolved_spell.targeting_type:
		SpellData.TargetingType.PROJECTILE:
			if effect_node is not ArcaneBolt:
				_refund_invalid_effect(effect_node, resolved_spell.mana_cost)
				return false
			var projectile: ArcaneBolt = effect_node as ArcaneBolt
			projectile.global_position = cast_origin.global_position
			projectile.configure(direction.normalized(), resolved_spell, caster_body, caster_faction)
		SpellData.TargetingType.AREA:
			if effect_node is not FrostCircle:
				_refund_invalid_effect(effect_node, resolved_spell.mana_cost)
				return false
			var area_effect: FrostCircle = effect_node as FrostCircle
			var normal: Vector3 = surface_normal.normalized() if surface_normal.length_squared() > 0.001 \
				else Vector3.UP
			area_effect.global_position = resolved_target + normal * 0.04
			area_effect.configure(resolved_spell, caster_faction)
		SpellData.TargetingType.CHAIN:
			if effect_node is not ChainLightning:
				_refund_invalid_effect(effect_node, resolved_spell.mana_cost)
				return false
			var chain_effect: ChainLightning = effect_node as ChainLightning
			chain_effect.global_position = cast_origin.global_position
			if not chain_effect.configure(resolved_spell, caster_faction, caster_body, resolved_target):
				mana_component.restore(resolved_spell.mana_cost)
				chain_effect.queue_free()
				_cancel_combat_cast()
				cast_failed.emit(FAILURE_INVALID_TARGET)
				return false
		_:
			_refund_invalid_effect(effect_node, resolved_spell.mana_cost)
			return false

	_cooldown_timer.start(resolved_spell.cooldown_seconds)
	set_process(true)
	cooldown_changed.emit(_cooldown_timer.time_left, _cooldown_timer.wait_time)
	cast_direction_resolved.emit(direction.normalized())
	spell_cast.emit(spell_data)
	return true


func get_cooldown_remaining() -> float:
	return _cooldown_timer.time_left


func get_effective_cooldown(spell: SpellData = null) -> float:
	var definition: SpellData = spell if spell != null else spell_data
	if definition == null:
		return 0.0
	var multiplier: float = 1.0
	if _modifier_provider.is_valid():
		var profile: Dictionary = _modifier_provider.call(definition) as Dictionary
		multiplier = float(profile.get("cooldown_multiplier", 1.0))
	return maxf(0.05, definition.cooldown_seconds * multiplier)


func has_pending_cast_request() -> bool:
	return _cast_request_pending


func _resolve_camera_aim(screen_position: Vector2, gamepad_request: bool) -> Dictionary:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or not is_instance_valid(cast_origin) or spell_data == null:
		return {}
	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_position).normalized()
	if ray_direction.length_squared() <= 0.001:
		return {}
	if gamepad_request:
		var assisted_target: HurtboxComponent = _find_assisted_target(ray_origin, ray_direction)
		if is_instance_valid(assisted_target):
			return _resolve_cast_origin_obstruction(
				assisted_target.global_position,
				-ray_direction,
				true
			)

	var collision_mask: int = WORLD_COLLISION_MASK
	if spell_data.targeting_type != SpellData.TargetingType.AREA:
		collision_mask |= ENEMY_COLLISION_MASK | HURTBOX_COLLISION_MASK
	var ray_end: Vector3 = ray_origin + ray_direction * maximum_camera_ray_distance
	var camera_hit: Dictionary = _intersect_ray(ray_origin, ray_end, collision_mask)
	if camera_hit.is_empty():
		if spell_data.targeting_type == SpellData.TargetingType.AREA:
			return {}
		var fallback_target: Vector3 = cast_origin.global_position \
			+ ray_direction * spell_data.range_meters
		return _resolve_cast_origin_obstruction(fallback_target, -ray_direction, false)
	return _resolve_cast_origin_obstruction(
		camera_hit[&"position"] as Vector3,
		camera_hit[&"normal"] as Vector3,
		false
	)


func _resolve_cast_origin_obstruction(
	desired_target: Vector3,
	surface_normal: Vector3,
	assisted: bool
) -> Dictionary:
	var direction: Vector3 = desired_target - cast_origin.global_position
	if direction.length_squared() <= 0.001:
		return {}
	if direction.length() > spell_data.range_meters:
		desired_target = cast_origin.global_position + direction.normalized() * spell_data.range_meters
	var obstruction: Dictionary = _intersect_ray(
		cast_origin.global_position,
		desired_target,
		WORLD_COLLISION_MASK
	)
	if not obstruction.is_empty():
		desired_target = obstruction[&"position"] as Vector3
		surface_normal = obstruction[&"normal"] as Vector3
	return {
		&"position": desired_target,
		&"normal": surface_normal,
		&"assisted": assisted,
	}


func _find_assisted_target(ray_origin: Vector3, ray_direction: Vector3) -> HurtboxComponent:
	var candidates: Array[HurtboxComponent] = []
	for node: Node in get_tree().get_nodes_in_group(&"hurtbox"):
		if node is HurtboxComponent:
			var hurtbox: HurtboxComponent = node as HurtboxComponent
			if hurtbox.faction == &"enemy" and not hurtbox.belongs_to(caster_faction):
				if is_instance_valid(hurtbox.health_component) \
						and not hurtbox.health_component.is_alive():
					continue
				candidates.append(hurtbox)
	var assisted_target: HurtboxComponent = _aim_assist_resolver.choose_target(
		ray_origin,
		ray_direction,
		candidates,
		spell_data.range_meters + ray_origin.distance_to(cast_origin.global_position),
		gamepad_assist_cone_degrees
	)
	if not is_instance_valid(assisted_target):
		return null
	var obstruction: Dictionary = _intersect_ray(
		ray_origin,
		assisted_target.global_position,
		WORLD_COLLISION_MASK
	)
	return null if not obstruction.is_empty() else assisted_target


func _intersect_ray(from: Vector3, to: Vector3, collision_mask: int) -> Dictionary:
	if not is_instance_valid(caster_body) or not caster_body.is_inside_tree():
		return {}
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from,
		to,
		collision_mask,
		_get_excluded_rids()
	)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.hit_from_inside = true
	return caster_body.get_world_3d().direct_space_state.intersect_ray(query)


func _get_excluded_rids() -> Array[RID]:
	var excluded: Array[RID] = []
	if caster_body is CollisionObject3D:
		excluded.append((caster_body as CollisionObject3D).get_rid())
	for child: Node in caster_body.find_children("*", "CollisionObject3D", true, false):
		if child is CollisionObject3D:
			excluded.append((child as CollisionObject3D).get_rid())
	return excluded


func _uses_camera_center_aim() -> bool:
	var camera: Camera3D = get_viewport().get_camera_3d()
	return camera != null and camera.projection == Camera3D.PROJECTION_PERSPECTIVE \
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _get_viewport_center() -> Vector2:
	return get_viewport().get_visible_rect().size * 0.5


func _is_configured() -> bool:
	return spell_data != null \
		and spell_data.is_valid_definition() \
		and spell_data.projectile_scene != null \
		and is_instance_valid(caster_body) \
		and is_instance_valid(cast_origin) \
		and is_instance_valid(mana_component)


func _cancel_combat_cast() -> void:
	if is_instance_valid(combat_state):
		combat_state.cancel_cast()


func _refund_invalid_effect(effect_node: Node, spent_mana: float) -> void:
	mana_component.restore(spent_mana)
	effect_node.queue_free()
	_cancel_combat_cast()
	cast_failed.emit(FAILURE_NOT_CONFIGURED)


func _on_cooldown_finished() -> void:
	set_process(false)
	cooldown_changed.emit(0.0, _cooldown_timer.wait_time)


func _resolve_runtime_spell() -> SpellData:
	var resolved: SpellData = spell_data.duplicate(false) as SpellData
	if not _modifier_provider.is_valid():
		return resolved
	var profile: Dictionary = _modifier_provider.call(spell_data) as Dictionary
	resolved.cooldown_seconds = maxf(
		0.05,
		spell_data.cooldown_seconds * float(profile.get("cooldown_multiplier", 1.0))
	)
	resolved.mana_cost = maxf(
		0.0,
		spell_data.mana_cost * float(profile.get("mana_cost_multiplier", 1.0))
	)
	resolved.damage = maxf(
		0.0,
		spell_data.damage * float(profile.get("damage_multiplier", 1.0))
	)
	resolved.projectile_speed = maxf(
		0.0,
		spell_data.projectile_speed * float(profile.get("projectile_speed_multiplier", 1.0))
	)
	resolved.area_radius = maxf(
		0.25,
		spell_data.area_radius * float(profile.get("area_radius_multiplier", 1.0))
	)
	resolved.effect_duration = maxf(
		0.1,
		spell_data.effect_duration * float(profile.get("effect_duration_multiplier", 1.0))
	)
	resolved.chain_jump_range = maxf(
		0.5,
		spell_data.chain_jump_range * float(profile.get("chain_jump_multiplier", 1.0))
	)
	return resolved
