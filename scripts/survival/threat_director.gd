class_name ThreatDirector
extends Node

signal threat_changed(score: float)
signal hunt_started()
signal hunt_ended()
signal raid_warning(raid_type: RaidType, seconds: float)
signal raid_started(raid_type: RaidType)
signal raid_ended(raid_type: RaidType)
signal stimulus_emitted(kind: StimulusKind, world_position: Vector3, intensity: float)
signal enemy_defeated(
	world_position: Vector3,
	trophy_item_id: StringName,
	knowledge_id: StringName
)

enum State {
	CALM,
	ROAMING,
	NIGHT_HUNT,
	RAID_WARNING,
}

enum RaidType {
	ASHEN_HUNT,
	SOUL_SIEGE,
}

enum StimulusKind {
	NOISE,
	MAGIC_LIGHT,
	FORBIDDEN_TRACE,
	WARD_BREACH,
}

@export var chaser_scene: PackedScene
@export var cultist_scene: PackedScene
@export var encounter_table: EncounterTableData
@export_range(1, 12, 1) var maximum_active_enemies: int = 8
@export_range(0.5, 10.0, 0.5) var evaluation_interval: float = 2.0
@export_range(1.0, 30.0, 0.5) var raid_warning_seconds: float = 8.0
@export_range(0.0, 300.0, 5.0) var raid_building_damage_cap: float = 90.0

var current_state: State = State.CALM
var current_raid_type: RaidType = RaidType.ASHEN_HUNT
var threat_score: float = 0.0
var _ritual_noise: float = 0.0
var _spawn_cursor: int = 0
var _last_hunt_day: int = 0
var _raid_damage_applied: float = 0.0
var _player: MagePlayer
var _world_clock: WorldClock
var _world_state: WorldState
var _construction_system: ConstructionSystem
var _spawn_host: Node3D
var _spawn_points: Array[Marker3D] = []
var _ward_zones: Array[WardZone] = []
var _active_enemies: Array[Node3D] = []
var _lair_active_counts: Dictionary[StringName, int] = {}
var _lair_respawn_ready_msec: Dictionary[StringName, int] = {}
var _warning_timer: Timer

@onready var _evaluation_timer: Timer = get_node("EvaluationTimer") as Timer


func _ready() -> void:
	_evaluation_timer.wait_time = evaluation_interval
	_evaluation_timer.timeout.connect(_evaluate)
	_warning_timer = Timer.new()
	_warning_timer.name = "RaidWarningTimer"
	_warning_timer.one_shot = true
	_warning_timer.timeout.connect(_activate_pending_raid)
	add_child(_warning_timer)


func bind(
	player: MagePlayer,
	clock: WorldClock,
	spawn_host: Node3D,
	spawn_points_root: Node3D,
	ward_zones: Array[WardZone],
	world_state: WorldState = null,
	construction_system: ConstructionSystem = null
) -> void:
	_player = player
	_world_clock = clock
	_spawn_host = spawn_host
	_ward_zones = ward_zones
	_world_state = world_state
	_construction_system = construction_system
	_spawn_points.clear()
	for child: Node in spawn_points_root.get_children():
		if child is Marker3D:
			_spawn_points.append(child as Marker3D)
	_initialize_lair_runtime()
	_restore_raid_state()
	_evaluation_timer.start()


func notify_ritual(magnitude: float, world_position: Vector3 = Vector3.INF) -> void:
	var position_3d: Vector3 = world_position
	if not position_3d.is_finite() and is_instance_valid(_player):
		position_3d = _player.global_position
	notify_stimulus(StimulusKind.NOISE, position_3d, magnitude)


func notify_stimulus(kind: StimulusKind, world_position: Vector3, intensity: float) -> void:
	var safe_intensity: float = maxf(0.0, intensity)
	if safe_intensity <= 0.0:
		return
	_ritual_noise = minf(70.0, _ritual_noise + safe_intensity * _stimulus_threat_weight(kind))
	stimulus_emitted.emit(kind, world_position, safe_intensity)
	var investigation_radius_squared: float = pow(safe_intensity * 1.6, 2.0)
	for enemy: Node3D in _active_enemies:
		if not is_instance_valid(enemy) \
				or enemy.global_position.distance_squared_to(world_position) > investigation_radius_squared:
			continue
		if enemy is ChaserEnemy:
			(enemy as ChaserEnemy).investigate(world_position)
		elif enemy is CultistEnemy:
			(enemy as CultistEnemy).investigate(world_position)
	if kind == StimulusKind.FORBIDDEN_TRACE and _is_night() and current_state == State.CALM:
		_begin_raid(RaidType.ASHEN_HUNT)


func force_night_hunt() -> void:
	_begin_raid(RaidType.ASHEN_HUNT, true, true)
	for _index: int in mini(3, maximum_active_enemies):
		_try_spawn_enemy(null, null, true)


func force_raid(raid_type: RaidType) -> void:
	_begin_raid(raid_type, true, true)


func force_ecology_group(size: int = 8) -> int:
	if encounter_table == null:
		return 0
	var spawned_count: int = 0
	for index: int in mini(size, maximum_active_enemies):
		var role: EnemyRoleData = encounter_table.roles[index % encounter_table.roles.size()]
		if _try_spawn_enemy(role, null, true):
			spawned_count += 1
	return spawned_count


func clear_runtime_enemies() -> void:
	_clear_runtime_enemies(true)


func set_encounter_table(next_table: EncounterTableData) -> void:
	_clear_runtime_enemies(false)
	encounter_table = next_table
	_initialize_lair_runtime()


func set_ward_zones(next_zones: Array[WardZone]) -> void:
	_ward_zones = next_zones


func sync_from_world_state() -> void:
	_clear_runtime_enemies(false)
	_restore_raid_state()


func _clear_runtime_enemies(persist_clear: bool) -> void:
	for enemy: Node3D in _active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_active_enemies.clear()
	_initialize_lair_runtime()
	_warning_timer.stop()
	current_state = State.CALM
	if persist_clear:
		_persist_raid_state(false)


func get_active_enemy_count() -> int:
	_prune_enemies()
	return _active_enemies.size()


func get_active_role_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for enemy: Node3D in _active_enemies:
		var role_id: StringName = _enemy_role_id(enemy)
		if not role_id.is_empty():
			ids.append(role_id)
	return ids


func get_lair_population(lair_id: StringName) -> int:
	return _lair_active_counts.get(lair_id, 0)


func get_raid_damage_applied() -> float:
	return _raid_damage_applied


func is_spawn_position_safe(world_position: Vector3, ignore_visibility: bool = false) -> bool:
	if not is_instance_valid(_player):
		return false
	var distance: float = world_position.distance_to(_player.global_position)
	if distance < 16.0 or distance > 78.0 or _is_warded(world_position):
		return false
	var camera: Camera3D = get_viewport().get_camera_3d()
	return ignore_visibility or not is_instance_valid(camera) \
		or not camera.is_position_in_frustum(world_position + Vector3.UP)


func _evaluate() -> void:
	if not is_instance_valid(_player) or not is_instance_valid(_world_clock):
		return
	_prune_enemies()
	_ritual_noise = maxf(0.0, _ritual_noise - 1.5)
	var corruption: float = _current_corruption()
	threat_score = _ritual_noise + (24.0 if _is_night() else 0.0) + corruption * 0.16
	threat_changed.emit(threat_score)
	if _is_night() and threat_score >= 36.0 and current_state == State.CALM \
			and not _raid_already_started_today():
		var raid_type: RaidType = RaidType.SOUL_SIEGE if _has_active_building_ward() \
			else RaidType.ASHEN_HUNT
		_begin_raid(raid_type)
	if current_state == State.NIGHT_HUNT:
		if not _is_night():
			_end_hunt()
		else:
			if _active_enemies.size() < maximum_active_enemies:
				_try_spawn_enemy()
			_apply_raid_pressure()
	elif current_state == State.CALM or current_state == State.ROAMING:
		_populate_one_lair()
		if threat_score >= 20.0 and _active_enemies.size() < 2:
			current_state = State.ROAMING
			_try_spawn_enemy()


func _begin_raid(raid_type: RaidType, immediate: bool = false, forced: bool = false) -> void:
	if current_state == State.NIGHT_HUNT or current_state == State.RAID_WARNING:
		return
	if not forced and _raid_already_started_today():
		return
	current_raid_type = raid_type
	_raid_damage_applied = 0.0
	_last_hunt_day = _world_clock.day_number if is_instance_valid(_world_clock) else _last_hunt_day + 1
	if immediate:
		_activate_pending_raid()
		return
	current_state = State.RAID_WARNING
	_warning_timer.start(raid_warning_seconds)
	_persist_raid_state(true, true)
	raid_warning.emit(current_raid_type, raid_warning_seconds)


func _activate_pending_raid() -> void:
	current_state = State.NIGHT_HUNT
	_persist_raid_state(true)
	raid_started.emit(current_raid_type)
	hunt_started.emit()


func _end_hunt() -> void:
	var ended_type: RaidType = current_raid_type
	current_state = State.CALM
	_persist_raid_state(false)
	raid_ended.emit(ended_type)
	hunt_ended.emit()


func _try_spawn_enemy(
	role_override: EnemyRoleData = null,
	lair: EnemyLairData = null,
	forced: bool = false
) -> bool:
	if _active_enemies.size() >= maximum_active_enemies or not is_instance_valid(_spawn_host):
		return false
	var spawn_position: Vector3 = _find_spawn_position(lair, forced)
	if not spawn_position.is_finite():
		return false
	var role: EnemyRoleData = role_override if role_override != null else _choose_role(lair)
	if role == null:
		return false
	var scene: PackedScene = cultist_scene \
		if role.controller_kind == EnemyRoleData.ControllerKind.CULTIST else chaser_scene
	if scene == null:
		return false
	var spawned: Node = scene.instantiate()
	if spawned is not Node3D:
		spawned.queue_free()
		return false
	var enemy: Node3D = spawned as Node3D
	_spawn_host.add_child(enemy)
	enemy.global_position = spawn_position
	var mutation: EnemyMutationData = _choose_mutation(role)
	if enemy is ChaserEnemy:
		var chaser: ChaserEnemy = enemy as ChaserEnemy
		chaser.respawns = false
		chaser.aggro_range = 24.0 * _player.get_corruption_component().get_enemy_detection_multiplier()
		chaser.disengage_range = 42.0
		chaser.configure_ecology(role, mutation)
		chaser.set_combat_target(_player)
		if lair != null:
			chaser.set_patrol_route(lair.patrol_points)
		chaser.defeated.connect(_on_enemy_defeated)
	elif enemy is CultistEnemy:
		var cultist: CultistEnemy = enemy as CultistEnemy
		cultist.aggro_range = 30.0
		cultist.disengage_range = 45.0
		cultist.configure_ecology(role, mutation)
		cultist.set_combat_target(_player)
		if lair != null:
			cultist.set_patrol_route(lair.patrol_points)
		cultist.defeated.connect(_on_enemy_defeated)
	else:
		enemy.queue_free()
		return false
	if lair != null:
		enemy.set_meta(&"lair_id", String(lair.lair_id))
		_lair_active_counts[lair.lair_id] = _lair_active_counts.get(lair.lair_id, 0) + 1
	enemy.reset_physics_interpolation()
	_active_enemies.append(enemy)
	_spawn_cursor += 1
	return true


func _find_spawn_position(lair: EnemyLairData, forced: bool) -> Vector3:
	var candidates: Array[Vector3] = []
	if lair != null:
		candidates.append(lair.world_position)
		candidates.append_array(lair.patrol_points)
	else:
		for offset: int in _spawn_points.size():
			var marker_position: Vector3 = _spawn_points[
				(_spawn_cursor + offset) % _spawn_points.size()
			].global_position
			var angle: float = float(_spawn_cursor + offset) * 2.399963
			candidates.append(marker_position + Vector3(cos(angle), 0.0, sin(angle)) * 3.5)
	for candidate: Vector3 in candidates:
		if is_spawn_position_safe(candidate, forced) and not _is_spawn_crowded(candidate):
			return candidate
	return Vector3.INF


func _choose_role(lair: EnemyLairData) -> EnemyRoleData:
	if encounter_table == null or encounter_table.roles.is_empty():
		return null
	var entries: Array[EncounterEntryData] = encounter_table.get_matching_entries(
		_is_night(), _current_corruption(), _world_state.region_tier if _world_state != null else 1,
		lair.poi_kind if lair != null else -1
	)
	var preferred: EncounterEntryData = encounter_table.get_entry(lair.encounter_id) \
		if lair != null else null
	var entry: EncounterEntryData = preferred if preferred != null and entries.has(preferred) \
		else (entries[_spawn_cursor % entries.size()] if not entries.is_empty() else null)
	if entry == null or entry.role_ids.is_empty():
		return encounter_table.roles[_spawn_cursor % encounter_table.roles.size()]
	return encounter_table.get_role(entry.role_ids[_spawn_cursor % entry.role_ids.size()])


func _choose_mutation(role: EnemyRoleData) -> EnemyMutationData:
	if encounter_table == null or role == null or role.role_id != &"hollow_elite_hunter":
		return null
	var available: Array[EnemyMutationData] = []
	for mutation: EnemyMutationData in encounter_table.mutations:
		if mutation != null and _current_corruption() >= mutation.minimum_corruption:
			available.append(mutation)
	return available[_spawn_cursor % available.size()] if not available.is_empty() else null


func _populate_one_lair() -> void:
	if encounter_table == null or encounter_table.lairs.is_empty() \
			or _active_enemies.size() >= maximum_active_enemies:
		return
	var now_msec: int = Time.get_ticks_msec()
	for offset: int in encounter_table.lairs.size():
		var lair: EnemyLairData = encounter_table.lairs[(_spawn_cursor + offset) % encounter_table.lairs.size()]
		if _lair_active_counts.get(lair.lair_id, 0) >= lair.population_budget \
				or now_msec < _lair_respawn_ready_msec.get(lair.lair_id, 0):
			continue
		if _try_spawn_enemy(null, lair):
			return


func _on_enemy_defeated(enemy: Node) -> void:
	if enemy is not Node3D:
		return
	var enemy_3d: Node3D = enemy as Node3D
	_release_lair_population(enemy_3d)
	_active_enemies.erase(enemy_3d)
	var trophy_id: StringName = &"soul_shard"
	var unlocked_knowledge: StringName = &""
	if enemy_3d is ChaserEnemy:
		trophy_id = (enemy_3d as ChaserEnemy).trophy_item_id
		unlocked_knowledge = (enemy_3d as ChaserEnemy).knowledge_id
	elif enemy_3d is CultistEnemy:
		trophy_id = (enemy_3d as CultistEnemy).trophy_item_id
		unlocked_knowledge = (enemy_3d as CultistEnemy).knowledge_id
	enemy_defeated.emit(enemy_3d.global_position, trophy_id, unlocked_knowledge)


func _apply_raid_pressure() -> void:
	if _construction_system == null or _raid_damage_applied >= raid_building_damage_cap:
		return
	var pieces: Array[BuildingPiece] = _construction_system.get_building_pieces()
	if pieces.is_empty():
		return
	var remaining_cap: float = raid_building_damage_cap - _raid_damage_applied
	var result: Dictionary = _construction_system.apply_raid_damage(
		pieces[0].global_position,
		36.0,
		minf(12.0, remaining_cap),
		2,
		current_raid_type == RaidType.SOUL_SIEGE
	)
	_raid_damage_applied += float(result.get("applied_damage", 0.0))
	for breach_position: Vector3 in result.get("breached_wards", []) as Array[Vector3]:
		notify_stimulus(StimulusKind.WARD_BREACH, breach_position, 18.0)
	_persist_raid_state(true)


func _has_active_building_ward() -> bool:
	if _construction_system == null:
		return false
	for piece: BuildingPiece in _construction_system.get_building_pieces():
		if piece.piece_data.functional_kind == BuildingPieceData.FunctionalKind.WARD \
				and piece.get_ward_fuel() > 0:
			return true
	return false


func _persist_raid_state(active: bool, warning: bool = false) -> void:
	if _world_state == null:
		return
	_world_state.raid_state = {
		"active": active,
		"warning": warning,
		"raid_type": int(current_raid_type),
		"started_day": _last_hunt_day,
		"damage_applied": _raid_damage_applied,
	}
	_world_state.state_changed.emit()


func _restore_raid_state() -> void:
	if _world_state == null or _world_state.raid_state.is_empty():
		return
	var state: Dictionary = _world_state.raid_state
	_last_hunt_day = int(state.get("started_day", 0))
	current_raid_type = clampi(
		int(state.get("raid_type", RaidType.ASHEN_HUNT)),
		RaidType.ASHEN_HUNT,
		RaidType.SOUL_SIEGE
	) as RaidType
	_raid_damage_applied = clampf(
		float(state.get("damage_applied", 0.0)), 0.0, raid_building_damage_cap
	)
	if bool(state.get("active", false)):
		current_state = State.RAID_WARNING if bool(state.get("warning", false)) else State.NIGHT_HUNT
		if current_state == State.RAID_WARNING:
			_warning_timer.start(raid_warning_seconds)


func _raid_already_started_today() -> bool:
	return is_instance_valid(_world_clock) and _last_hunt_day == _world_clock.day_number


func _current_corruption() -> float:
	return _player.get_corruption_component().current_corruption if is_instance_valid(_player) else 0.0


func _is_night() -> bool:
	return is_instance_valid(_world_clock) and _world_clock.is_night()


func _stimulus_threat_weight(kind: StimulusKind) -> float:
	match kind:
		StimulusKind.MAGIC_LIGHT:
			return 0.55
		StimulusKind.FORBIDDEN_TRACE:
			return 1.4
		StimulusKind.WARD_BREACH:
			return 1.15
		_:
			return 1.0


func _enemy_role_id(enemy: Node3D) -> StringName:
	if enemy is ChaserEnemy:
		return (enemy as ChaserEnemy).ecology_role_id
	if enemy is CultistEnemy:
		return (enemy as CultistEnemy).ecology_role_id
	return &""


func _is_warded(world_position: Vector3) -> bool:
	for ward: WardZone in _ward_zones:
		if is_instance_valid(ward) and ward.protects(world_position):
			return true
	return false


func _is_spawn_crowded(world_position: Vector3) -> bool:
	for enemy: Node3D in _active_enemies:
		if is_instance_valid(enemy) and enemy.global_position.distance_squared_to(world_position) < 2.25:
			return true
	return false


func _prune_enemies() -> void:
	for index: int in range(_active_enemies.size() - 1, -1, -1):
		var enemy: Node3D = _active_enemies[index]
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			if is_instance_valid(enemy):
				_release_lair_population(enemy)
			_active_enemies.remove_at(index)


func _release_lair_population(enemy: Node3D) -> void:
	if bool(enemy.get_meta(&"lair_released", false)):
		return
	var lair_id: StringName = StringName(String(enemy.get_meta(&"lair_id", "")))
	if lair_id.is_empty():
		return
	enemy.set_meta(&"lair_released", true)
	_lair_active_counts[lair_id] = maxi(0, _lair_active_counts.get(lair_id, 0) - 1)
	var definition: EnemyLairData = _find_lair(lair_id)
	if definition != null:
		_lair_respawn_ready_msec[lair_id] = Time.get_ticks_msec() \
			+ roundi(definition.respawn_seconds * 1000.0)


func _find_lair(lair_id: StringName) -> EnemyLairData:
	if encounter_table == null:
		return null
	for lair: EnemyLairData in encounter_table.lairs:
		if lair != null and lair.lair_id == lair_id:
			return lair
	return null


func _initialize_lair_runtime() -> void:
	_lair_active_counts.clear()
	_lair_respawn_ready_msec.clear()
	if encounter_table == null:
		return
	for lair: EnemyLairData in encounter_table.lairs:
		if lair != null:
			_lair_active_counts[lair.lair_id] = 0
			_lair_respawn_ready_msec[lair.lair_id] = 0
