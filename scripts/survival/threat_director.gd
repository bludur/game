class_name ThreatDirector
extends Node

signal threat_changed(score: float)
signal hunt_started()
signal hunt_ended()
signal enemy_defeated(world_position: Vector3)

enum State {
	CALM,
	ROAMING,
	NIGHT_HUNT,
}

@export var chaser_scene: PackedScene
@export var cultist_scene: PackedScene
@export_range(1, 12, 1) var maximum_active_enemies: int = 6
@export_range(0.5, 10.0, 0.5) var evaluation_interval: float = 2.0

var current_state: State = State.CALM
var threat_score: float = 0.0
var _ritual_noise: float = 0.0
var _spawn_cursor: int = 0
var _last_hunt_day: int = 0
var _player: MagePlayer
var _world_clock: WorldClock
var _spawn_host: Node3D
var _spawn_points: Array[Marker3D] = []
var _ward_zones: Array[WardZone] = []
var _active_enemies: Array[Node3D] = []

@onready var _evaluation_timer: Timer = get_node("EvaluationTimer") as Timer


func _ready() -> void:
	_evaluation_timer.wait_time = evaluation_interval
	_evaluation_timer.timeout.connect(_evaluate)


func bind(
		player: MagePlayer,
		clock: WorldClock,
		spawn_host: Node3D,
		spawn_points_root: Node3D,
		ward_zones: Array[WardZone]
) -> void:
	_player = player
	_world_clock = clock
	_spawn_host = spawn_host
	_ward_zones = ward_zones
	_spawn_points.clear()
	for child: Node in spawn_points_root.get_children():
		if child is Marker3D:
			_spawn_points.append(child as Marker3D)
	_evaluation_timer.start()


func notify_ritual(magnitude: float) -> void:
	_ritual_noise = minf(50.0, _ritual_noise + maxf(0.0, magnitude))


func force_night_hunt() -> void:
	_begin_hunt()
	for _index: int in mini(3, maximum_active_enemies):
		_try_spawn_enemy()


func clear_runtime_enemies() -> void:
	for enemy: Node3D in _active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_active_enemies.clear()
	current_state = State.CALM


func get_active_enemy_count() -> int:
	_prune_enemies()
	return _active_enemies.size()


func _evaluate() -> void:
	if not is_instance_valid(_player) or not is_instance_valid(_world_clock):
		return
	_prune_enemies()
	_ritual_noise = maxf(0.0, _ritual_noise - 1.5)
	threat_score = _ritual_noise
	if _world_clock.is_night():
		threat_score += 24.0
	threat_score += float(_player.get_corruption_component().get_threshold()) * 12.0
	threat_changed.emit(threat_score)
	if _world_clock.is_night() and threat_score >= 36.0 \
			and _last_hunt_day != _world_clock.day_number:
		_begin_hunt()
	if current_state == State.NIGHT_HUNT:
		if not _world_clock.is_night():
			_end_hunt()
		elif _active_enemies.size() < maximum_active_enemies:
			_try_spawn_enemy()
	elif threat_score >= 20.0 and _active_enemies.size() < 2:
		current_state = State.ROAMING
		_try_spawn_enemy()


func _begin_hunt() -> void:
	if current_state == State.NIGHT_HUNT:
		return
	current_state = State.NIGHT_HUNT
	_last_hunt_day = _world_clock.day_number if is_instance_valid(_world_clock) else _last_hunt_day + 1
	hunt_started.emit()


func _end_hunt() -> void:
	current_state = State.CALM
	hunt_ended.emit()


func _try_spawn_enemy() -> bool:
	if _spawn_points.is_empty() or not is_instance_valid(_spawn_host):
		return false
	var spawn_point: Marker3D
	for offset: int in _spawn_points.size():
		var candidate: Marker3D = _spawn_points[(_spawn_cursor + offset) % _spawn_points.size()]
		var distance: float = candidate.global_position.distance_to(_player.global_position)
		if distance < 16.0 or distance > 70.0 or _is_warded(candidate.global_position):
			continue
		var camera: Camera3D = get_viewport().get_camera_3d()
		if is_instance_valid(camera) and camera.is_position_in_frustum(candidate.global_position + Vector3.UP):
			continue
		spawn_point = candidate
		_spawn_cursor = (_spawn_cursor + offset + 1) % _spawn_points.size()
		break
	if spawn_point == null:
		return false
	var role_index: int = _spawn_cursor % 3
	var scene: PackedScene = cultist_scene if role_index == 2 else chaser_scene
	if scene == null:
		return false
	var spawned: Node = scene.instantiate()
	if spawned is not Node3D:
		spawned.queue_free()
		return false
	var enemy: Node3D = spawned as Node3D
	_spawn_host.add_child(enemy)
	enemy.global_position = spawn_point.global_position
	enemy.reset_physics_interpolation()
	if enemy is ChaserEnemy:
		var chaser: ChaserEnemy = enemy as ChaserEnemy
		chaser.respawns = false
		chaser.aggro_range = 24.0 * _player.get_corruption_component().get_enemy_detection_multiplier()
		chaser.disengage_range = 38.0
		if role_index == 1:
			chaser.move_speed = 4.2
			chaser.attack_damage = 12.0
		chaser.set_combat_target(_player)
		chaser.defeated.connect(_on_enemy_defeated)
	elif enemy is CultistEnemy:
		var herald: CultistEnemy = enemy as CultistEnemy
		herald.aggro_range = 30.0
		herald.disengage_range = 42.0
		herald.set_combat_target(_player)
		herald.defeated.connect(_on_enemy_defeated)
	_active_enemies.append(enemy)
	return true


func _on_enemy_defeated(enemy: Node) -> void:
	if enemy is Node3D:
		enemy_defeated.emit((enemy as Node3D).global_position)


func _is_warded(world_position: Vector3) -> bool:
	for ward: WardZone in _ward_zones:
		if is_instance_valid(ward) and ward.protects(world_position):
			return true
	return false


func _prune_enemies() -> void:
	for index: int in range(_active_enemies.size() - 1, -1, -1):
		if not is_instance_valid(_active_enemies[index]) or _active_enemies[index].is_queued_for_deletion():
			_active_enemies.remove_at(index)
