class_name BossEncounter
extends Node3D

signal boss_spawned(boss: ArenaWarden)
signal boss_defeated()

@export var boss_scene: PackedScene
@export var hazard_scene: PackedScene
@export var chaser_scene: PackedScene
@export var cultist_scene: PackedScene

var _boss: ArenaWarden
var _target: MagePlayer
var _active_hazards: Array[BossHazard] = []
var _summoned_enemies: Array[Node] = []
var _summon_telegraphs: Array[MeshInstance3D] = []

@onready var _boss_host: Node3D = get_node("BossHost") as Node3D
@onready var _hazard_host: Node3D = get_node("HazardHost") as Node3D
@onready var _summoned_host: Node3D = get_node("SummonedEnemies") as Node3D
@onready var _boss_spawn: Marker3D = get_node("BossSpawn") as Marker3D
@onready var _summon_points: Node3D = get_node("SummonPoints") as Node3D
@onready var _cleanup_timer: Timer = get_node("CleanupTimer") as Timer


func _ready() -> void:
	_cleanup_timer.timeout.connect(_retire_boss)


func start_encounter(target: MagePlayer) -> bool:
	if boss_scene == null or hazard_scene == null or not is_instance_valid(target):
		return false
	stop_and_clear()
	_target = target
	var boss_node: Node = boss_scene.instantiate()
	if boss_node is not ArenaWarden:
		boss_node.queue_free()
		return false
	_boss = boss_node as ArenaWarden
	_boss_host.add_child(_boss)
	_boss.global_position = _boss_spawn.global_position
	_boss.reset_physics_interpolation()
	_boss.telegraph_started.connect(_on_telegraph_started)
	_boss.attack_committed.connect(_on_attack_committed)
	_boss.attack_cancelled.connect(_cancel_pending_attacks)
	_boss.boss_defeated.connect(_on_boss_defeated)
	if not _boss.start_encounter(target):
		_boss.queue_free()
		_boss = null
		return false
	boss_spawned.emit(_boss)
	return true


func stop_and_clear() -> void:
	_cleanup_timer.stop()
	_cancel_pending_attacks()
	for enemy: Node in _summoned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_summoned_enemies.clear()
	if is_instance_valid(_boss):
		_boss.stop_encounter()
		_boss.queue_free()
	_boss = null


func get_boss() -> ArenaWarden:
	return _boss


func get_summoned_enemies() -> Array[Node]:
	var alive: Array[Node] = []
	for enemy: Node in _summoned_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			alive.append(enemy)
	return alive


func get_active_hazard_count() -> int:
	var count: int = 0
	for hazard: BossHazard in _active_hazards:
		if is_instance_valid(hazard) and not hazard.is_queued_for_deletion():
			count += 1
	return count


func _on_telegraph_started(attack: BossAttackData) -> void:
	_cancel_pending_attacks()
	if attack.attack_type == BossAttackData.AttackType.SUMMON:
		_create_summon_telegraphs()
		return
	var hazard_node: Node = hazard_scene.instantiate()
	if hazard_node is not BossHazard:
		hazard_node.queue_free()
		return
	var hazard: BossHazard = hazard_node as BossHazard
	_hazard_host.add_child(hazard)
	var direction: Vector3 = Vector3.FORWARD
	if is_instance_valid(_target) and is_instance_valid(_boss):
		direction = _target.global_position - _boss.global_position
	hazard.configure(attack, _boss.global_position, direction)
	_active_hazards.append(hazard)


func _on_attack_committed(attack: BossAttackData) -> void:
	if attack.attack_type == BossAttackData.AttackType.SUMMON:
		_clear_summon_telegraphs()
		_spawn_guard_pair()
		return
	for hazard: BossHazard in _active_hazards:
		if is_instance_valid(hazard):
			hazard.activate()


func _spawn_guard_pair() -> void:
	var scenes: Array[PackedScene] = [chaser_scene, cultist_scene]
	var points: Array[Node] = _summon_points.get_children()
	for index: int in scenes.size():
		var scene: PackedScene = scenes[index]
		if scene == null:
			continue
		var enemy: Node = scene.instantiate()
		_summoned_host.add_child(enemy)
		if enemy is Node3D and index < points.size() and points[index] is Marker3D:
			(enemy as Node3D).global_position = (points[index] as Marker3D).global_position
			(enemy as Node3D).reset_physics_interpolation()
		if enemy is ChaserEnemy:
			var chaser: ChaserEnemy = enemy as ChaserEnemy
			chaser.respawns = false
			chaser.set_combat_target(_target)
		elif enemy is CultistEnemy:
			(enemy as CultistEnemy).set_combat_target(_target)
		_summoned_enemies.append(enemy)


func _create_summon_telegraphs() -> void:
	for point: Node in _summon_points.get_children():
		if point is not Marker3D:
			continue
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = 1.1
		mesh.bottom_radius = 1.1
		mesh.height = 0.04
		mesh.radial_segments = 32
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(1.0, 0.15, 0.3, 0.38)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.04, 0.2, 1.0)
		material.emission_energy_multiplier = 2.8
		mesh.material = material
		var visual: MeshInstance3D = MeshInstance3D.new()
		visual.mesh = mesh
		_hazard_host.add_child(visual)
		visual.global_position = (point as Marker3D).global_position + Vector3.UP * 0.04
		_summon_telegraphs.append(visual)


func _cancel_pending_attacks() -> void:
	for hazard: BossHazard in _active_hazards:
		if is_instance_valid(hazard):
			hazard.cancel()
	_active_hazards.clear()
	_clear_summon_telegraphs()


func _clear_summon_telegraphs() -> void:
	for visual: MeshInstance3D in _summon_telegraphs:
		if is_instance_valid(visual):
			visual.queue_free()
	_summon_telegraphs.clear()


func _on_boss_defeated(_defeated_boss: ArenaWarden) -> void:
	_cancel_pending_attacks()
	for enemy: Node in _summoned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_summoned_enemies.clear()
	boss_defeated.emit()
	_cleanup_timer.start(0.8)


func _retire_boss() -> void:
	if is_instance_valid(_boss):
		_boss.queue_free()
	_boss = null
