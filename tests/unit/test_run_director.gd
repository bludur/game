extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")


func test_complete_run_reaches_upgrade_victory_and_clean_restart() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var director: RunDirector = main.get_node("RunDirector") as RunDirector
	var waves: WaveDirector = main.get_node("WaveDirector") as WaveDirector
	var player: MagePlayer = get_tree().get_first_node_in_group(&"player") as MagePlayer
	var session_ui: SessionUi = main.get_node("SessionUi") as SessionUi
	director.intermission_duration = 0.01
	director.start_new_run(true)
	player.get_hurtbox_component().grant_invulnerability(20.0)
	var base_damage: float = player.get_spell_loadout().get_spell(0).damage
	var base_regeneration: float = player.get_mana_component().regeneration_per_second
	var base_max_health: float = player.get_health_component().max_health

	await _defeat_current_wave(waves)
	for _frame: int in 4:
		await get_tree().physics_frame
	await _defeat_current_wave(waves)
	assert_eq(director.current_state, RunDirector.State.UPGRADE)
	assert_true(session_ui.is_upgrade_visible())
	assert_true(director.choose_upgrade(0))
	assert_eq(player.get_spell_loadout().get_spell(0).damage, base_damage + 8.0)
	assert_eq(director.get_applied_upgrade_ids(), [&"arcane_damage"])

	await _defeat_current_wave(waves)
	assert_eq(director.current_state, RunDirector.State.VICTORY)
	assert_true(session_ui.is_result_visible())

	assert_true(director.start_new_run(true))
	await get_tree().process_frame
	assert_eq(director.current_state, RunDirector.State.COMBAT)
	assert_eq(player.get_spell_loadout().get_spell(0).damage, base_damage)
	assert_true(director.get_applied_upgrade_ids().is_empty())
	assert_eq(player.get_health_component().current_health, player.get_health_component().max_health)

	player.get_hurtbox_component().grant_invulnerability(20.0)
	await _advance_to_upgrade(waves)
	assert_true(director.choose_upgrade(1))
	assert_eq(player.get_mana_component().regeneration_per_second, base_regeneration + 7.0)
	assert_true(director.start_new_run(true))
	await get_tree().process_frame
	assert_eq(player.get_mana_component().regeneration_per_second, base_regeneration)

	player.get_hurtbox_component().grant_invulnerability(20.0)
	await _advance_to_upgrade(waves)
	assert_true(director.choose_upgrade(2))
	assert_eq(player.get_health_component().max_health, base_max_health + 30.0)
	assert_eq(player.get_health_component().current_health, base_max_health + 30.0)
	assert_true(director.start_new_run(true))
	await get_tree().process_frame
	assert_eq(player.get_health_component().max_health, base_max_health)


func test_player_death_reaches_defeat_and_restart_restores_player() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var director: RunDirector = main.get_node("RunDirector") as RunDirector
	var waves: WaveDirector = main.get_node("WaveDirector") as WaveDirector
	var player: MagePlayer = get_tree().get_first_node_in_group(&"player") as MagePlayer
	var session_ui: SessionUi = main.get_node("SessionUi") as SessionUi
	director.start_new_run(true)
	player.get_health_component().take_damage(1000.0)
	await get_tree().process_frame

	assert_eq(director.current_state, RunDirector.State.DEFEAT)
	assert_eq(waves.get_current_wave_number(), 1)
	assert_true(session_ui.is_result_visible())
	assert_false(player.get_health_component().is_alive())
	assert_true(director.start_new_run(true))
	await get_tree().process_frame
	assert_true(player.get_health_component().is_alive())
	assert_eq(player.get_health_component().current_health, player.get_health_component().max_health)


func test_session_ui_uses_full_rect_overlays_and_accessible_buttons() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var session_ui: SessionUi = main.get_node("SessionUi") as SessionUi
	var root_control: Control = session_ui.get_node("Root") as Control
	var choice_overlay: Control = session_ui.get_node("Root/ChoiceOverlay") as Control
	var result_overlay: Control = session_ui.get_node("Root/ResultOverlay") as Control
	var first_button: Button = session_ui.get_node(
		"Root/ChoiceOverlay/Center/Card/Content/Choices/Damage"
	) as Button

	assert_eq(root_control.anchor_right, 1.0)
	assert_eq(root_control.anchor_bottom, 1.0)
	assert_eq(choice_overlay.anchor_right, 1.0)
	assert_eq(result_overlay.anchor_bottom, 1.0)
	assert_gte(first_button.custom_minimum_size.y, 44.0)
	assert_eq(first_button.focus_mode, Control.FOCUS_ALL)


func _defeat_current_wave(waves: WaveDirector) -> void:
	var expected: int = waves.get_remaining_count()
	for _frame: int in 180:
		if waves.get_spawned_enemies().size() == expected:
			break
		await get_tree().physics_frame
	assert_eq(waves.get_spawned_enemies().size(), expected)
	for enemy: Node in waves.get_spawned_enemies():
		if enemy is ChaserEnemy:
			(enemy as ChaserEnemy).get_health_component().take_damage(1000.0)
		elif enemy is CultistEnemy:
			(enemy as CultistEnemy).get_health_component().take_damage(1000.0)
	await get_tree().process_frame


func _advance_to_upgrade(waves: WaveDirector) -> void:
	await _defeat_current_wave(waves)
	for _frame: int in 4:
		await get_tree().physics_frame
	await _defeat_current_wave(waves)
