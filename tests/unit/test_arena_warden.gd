extends GutTest

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player/player.tscn")
const BOSS_SCENE: PackedScene = preload("res://scenes/boss/arena_warden.tscn")
const HAZARD_SCENE: PackedScene = preload("res://scenes/boss/boss_hazard.tscn")
const WAVE_ATTACK: BossAttackData = preload("res://resources/boss_attacks/expanding_wave.tres")


func test_phase_change_occurs_once_and_death_stops_the_fsm() -> void:
	var world: Node3D = Node3D.new()
	add_child_autofree(world)
	var player: MagePlayer = PLAYER_SCENE.instantiate() as MagePlayer
	var boss: ArenaWarden = BOSS_SCENE.instantiate() as ArenaWarden
	world.add_child(player)
	world.add_child(boss)
	var phase_events: Array[int] = []
	var defeated_events: Array[bool] = []
	boss.phase_changed.connect(func(phase: int) -> void: phase_events.append(phase))
	boss.boss_defeated.connect(func(_warden: ArenaWarden) -> void: defeated_events.append(true))

	assert_true(boss.start_encounter(player))
	assert_eq(boss.current_state, ArenaWarden.State.ENTER)
	boss.get_health_component().take_damage(181.0)
	assert_eq(boss.current_phase, 2)
	assert_eq(phase_events, [2])
	boss.get_health_component().take_damage(20.0)
	assert_eq(phase_events, [2])
	boss.get_health_component().take_damage(1000.0)
	assert_eq(defeated_events.size(), 1)
	assert_eq(boss.current_state, ArenaWarden.State.DEFEATED)
	assert_false(boss.is_encounter_active())
	await get_tree().create_timer(0.2).timeout
	assert_eq(defeated_events.size(), 1)


func test_wave_hazard_only_damages_after_activation() -> void:
	var world: Node3D = Node3D.new()
	add_child_autofree(world)
	var player: MagePlayer = PLAYER_SCENE.instantiate() as MagePlayer
	var hazard: BossHazard = HAZARD_SCENE.instantiate() as BossHazard
	world.add_child(player)
	world.add_child(hazard)
	hazard.configure(WAVE_ATTACK, player.global_position, Vector3.FORWARD)
	var health: HealthComponent = player.get_health_component()
	var health_before: float = health.current_health
	for _frame: int in 2:
		await get_tree().physics_frame
	assert_eq(health.current_health, health_before)
	hazard.activate()
	for _frame: int in 5:
		await get_tree().physics_frame
	assert_eq(health.current_health, health_before - WAVE_ATTACK.damage)


func test_boss_death_cancels_pending_telegraph() -> void:
	var main: Node = preload("res://scenes/main/main.tscn").instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var encounter: BossEncounter = main.get_node("BossEncounter") as BossEncounter
	var player: MagePlayer = get_tree().get_first_node_in_group(&"player") as MagePlayer
	assert_true(encounter.start_encounter(player))
	var boss: ArenaWarden = encounter.get_boss()
	await get_tree().create_timer(0.95).timeout
	assert_eq(boss.current_state, ArenaWarden.State.TELEGRAPH)
	assert_eq(encounter.get_active_hazard_count(), 1)
	boss.get_health_component().take_damage(1000.0)
	await get_tree().process_frame
	assert_eq(encounter.get_active_hazard_count(), 0)
