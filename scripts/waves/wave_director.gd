class_name WaveDirector
extends Node

signal wave_started(wave_number: int, wave_name: String, total_enemies: int)
signal enemy_count_changed(remaining: int)
signal enemy_defeated(enemy: Node)
signal wave_completed(wave_number: int)
signal all_waves_completed()

const ENEMY_CHASER: StringName = &"chaser"
const ENEMY_CULTIST: StringName = &"cultist"

@export_group("Wave Definitions")
@export var wave_one: WaveData
@export var wave_two: WaveData
@export var wave_three: WaveData

@export_group("Spawning")
@export var chaser_scene: PackedScene
@export var cultist_scene: PackedScene
@export var auto_start: bool = true
@export var auto_advance: bool = true
@export_range(0.1, 10.0, 0.1) var time_between_waves: float = 2.0
@export_range(1.0, 12.0, 0.25) var minimum_player_distance: float = 5.0

var _current_wave_index: int = -1
var _remaining_enemies: int = 0
var _pending_enemy_types: Array[StringName] = []
var _spawned_enemies: Array[Node] = []
var _defeated_instance_ids: Dictionary = {}
var _spawn_point_cursor: int = 0
var _wave_active: bool = false

@onready var _enemies_container: Node3D = get_node("Enemies") as Node3D
@onready var _spawn_points: Node3D = get_node("SpawnPoints") as Node3D
@onready var _spawn_timer: Timer = get_node("SpawnTimer") as Timer
@onready var _inter_wave_timer: Timer = get_node("InterWaveTimer") as Timer


func _ready() -> void:
	_spawn_timer.timeout.connect(_spawn_next_enemy)
	_inter_wave_timer.timeout.connect(_on_inter_wave_timeout)
	if auto_start:
		call_deferred("start_wave", 0)


func start_wave(wave_index: int) -> bool:
	if _wave_active or wave_index < 0 or wave_index >= get_wave_count():
		return false
	var wave: WaveData = get_wave(wave_index)
	if wave == null or not wave.is_valid_definition():
		push_error("WaveDirector received an invalid wave definition at index %d." % wave_index)
		return false
	_current_wave_index = wave_index
	_pending_enemy_types.clear()
	for _index: int in wave.chaser_count:
		_pending_enemy_types.append(ENEMY_CHASER)
	for _index: int in wave.cultist_count:
		_pending_enemy_types.append(ENEMY_CULTIST)
	_remaining_enemies = _pending_enemy_types.size()
	_defeated_instance_ids.clear()
	_wave_active = true
	wave_started.emit(_current_wave_index + 1, wave.display_name, _remaining_enemies)
	enemy_count_changed.emit(_remaining_enemies)
	_spawn_next_enemy()
	if not _pending_enemy_types.is_empty():
		_spawn_timer.start(wave.spawn_interval)
	return true


func get_wave(wave_index: int) -> WaveData:
	match wave_index:
		0:
			return wave_one
		1:
			return wave_two
		2:
			return wave_three
		_:
			return null


func get_wave_count() -> int:
	return 3


func get_current_wave_number() -> int:
	return _current_wave_index + 1


func get_remaining_count() -> int:
	return _remaining_enemies


func is_wave_active() -> bool:
	return _wave_active


func get_spawned_enemies() -> Array[Node]:
	var alive_enemies: Array[Node] = []
	for enemy: Node in _spawned_enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy is ChaserEnemy and (enemy as ChaserEnemy).get_health_component().is_alive():
			alive_enemies.append(enemy)
		elif enemy is CultistEnemy and (enemy as CultistEnemy).get_health_component().is_alive():
			alive_enemies.append(enemy)
	return alive_enemies


func stop_and_clear() -> void:
	_spawn_timer.stop()
	_inter_wave_timer.stop()
	_pending_enemy_types.clear()
	for enemy: Node in _spawned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_spawned_enemies.clear()
	_defeated_instance_ids.clear()
	_remaining_enemies = 0
	_current_wave_index = -1
	_wave_active = false
	enemy_count_changed.emit(0)


func _spawn_next_enemy() -> void:
	if _pending_enemy_types.is_empty():
		_spawn_timer.stop()
		return
	var enemy_type: StringName = _pending_enemy_types.pop_front()
	var scene: PackedScene = chaser_scene if enemy_type == ENEMY_CHASER else cultist_scene
	if scene == null:
		push_error("WaveDirector is missing a scene for enemy type '%s'." % enemy_type)
		_register_failed_spawn()
		return
	var enemy: Node = scene.instantiate()
	_enemies_container.add_child(enemy)
	if enemy is Node3D:
		(enemy as Node3D).global_position = _choose_spawn_position()
		(enemy as Node3D).reset_physics_interpolation()
	if enemy is ChaserEnemy:
		var chaser: ChaserEnemy = enemy as ChaserEnemy
		chaser.respawns = false
		chaser.defeated.connect(_on_enemy_defeated)
	elif enemy is CultistEnemy:
		(enemy as CultistEnemy).defeated.connect(_on_enemy_defeated)
	else:
		push_error("WaveDirector spawned a scene without a supported enemy controller.")
		enemy.queue_free()
		_register_failed_spawn()
		return
	_spawned_enemies.append(enemy)
	if _pending_enemy_types.is_empty():
		_spawn_timer.stop()


func _choose_spawn_position() -> Vector3:
	var points: Array[Node] = _spawn_points.get_children()
	if points.is_empty():
		return Vector3.ZERO
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	for offset: int in points.size():
		var point_index: int = (_spawn_point_cursor + offset) % points.size()
		var point: Marker3D = points[point_index] as Marker3D
		if point == null:
			continue
		if not is_instance_valid(player) \
			or point.global_position.distance_to(player.global_position) >= minimum_player_distance:
			_spawn_point_cursor = (point_index + 1) % points.size()
			return point.global_position
	var fallback: Marker3D = points[_spawn_point_cursor % points.size()] as Marker3D
	_spawn_point_cursor = (_spawn_point_cursor + 1) % points.size()
	return fallback.global_position if fallback != null else Vector3.ZERO


func _on_enemy_defeated(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	var instance_id: int = enemy.get_instance_id()
	if _defeated_instance_ids.has(instance_id):
		return
	_defeated_instance_ids[instance_id] = true
	_remaining_enemies = maxi(_remaining_enemies - 1, 0)
	enemy_defeated.emit(enemy)
	enemy_count_changed.emit(_remaining_enemies)
	if _remaining_enemies == 0 and _pending_enemy_types.is_empty():
		_complete_current_wave()


func _register_failed_spawn() -> void:
	_remaining_enemies = maxi(_remaining_enemies - 1, 0)
	enemy_count_changed.emit(_remaining_enemies)
	if _remaining_enemies == 0 and _pending_enemy_types.is_empty():
		_complete_current_wave()


func _complete_current_wave() -> void:
	if not _wave_active:
		return
	_wave_active = false
	wave_completed.emit(_current_wave_index + 1)
	if _current_wave_index >= get_wave_count() - 1:
		all_waves_completed.emit()
	elif auto_advance:
		_inter_wave_timer.start(time_between_waves)


func _on_inter_wave_timeout() -> void:
	start_wave(_current_wave_index + 1)
