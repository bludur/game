extends GutTest

const WAVE_DIRECTOR_SCENE: PackedScene = preload("res://scenes/waves/wave_director.tscn")
const TRAINING_TARGET_SCENE: PackedScene = preload("res://scenes/targets/training_target.tscn")


func test_wave_definitions_are_valid_and_escalate() -> void:
	var director: WaveDirector = WAVE_DIRECTOR_SCENE.instantiate() as WaveDirector
	director.auto_start = false
	add_child_autofree(director)

	assert_eq(director.get_wave_count(), 3)
	assert_true(director.get_wave(0).is_valid_definition())
	assert_true(director.get_wave(1).is_valid_definition())
	assert_true(director.get_wave(2).is_valid_definition())
	assert_lt(director.get_wave(0).get_total_enemy_count(), director.get_wave(2).get_total_enemy_count())
	assert_gt(director.get_wave(1).cultist_count, 0)


func test_all_three_waves_complete_and_ignore_training_targets() -> void:
	var world: Node3D = Node3D.new()
	add_child_autofree(world)
	var training_target: TrainingTarget = TRAINING_TARGET_SCENE.instantiate() as TrainingTarget
	world.add_child(training_target)
	var director: WaveDirector = WAVE_DIRECTOR_SCENE.instantiate() as WaveDirector
	director.auto_start = false
	director.auto_advance = false
	world.add_child(director)
	var completed_waves: Array[int] = []
	director.wave_completed.connect(func(wave_number: int) -> void: completed_waves.append(wave_number))

	for wave_index: int in director.get_wave_count():
		assert_true(director.start_wave(wave_index))
		var spawn_frames: int = ceili(
			director.get_wave(wave_index).spawn_interval
			* director.get_wave(wave_index).get_total_enemy_count()
			* 60.0
		) + 8
		for _frame: int in spawn_frames:
			await get_tree().physics_frame
		assert_eq(director.get_remaining_count(), director.get_wave(wave_index).get_total_enemy_count())
		assert_eq(director.get_spawned_enemies().size(), director.get_remaining_count())
		for enemy: Node in director.get_spawned_enemies():
			if enemy is ChaserEnemy:
				(enemy as ChaserEnemy).get_health_component().take_damage(1000.0)
			elif enemy is CultistEnemy:
				(enemy as CultistEnemy).get_health_component().take_damage(1000.0)
		await get_tree().process_frame
		assert_eq(director.get_remaining_count(), 0)
		assert_false(director.is_wave_active())

	assert_eq(completed_waves, [1, 2, 3])
	assert_true(training_target.get_health_component().is_alive())
