extends SceneTree

const APP_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const SESSION_COUNT: int = 5

var _failures: Array[String] = []
var _records: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var baseline_orphans: int = roundi(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var app: AppRoot = APP_SCENE.instantiate() as AppRoot
	root.add_child(app)
	await process_frame
	await _check_settings_round_trip(app)

	for session_index: int in SESSION_COUNT:
		await _run_session(app, session_index, session_index == SESSION_COUNT - 1)

	_check(app.get_current_run() == null, "App retained a run after returning to the menu.")
	_check(app.get_node("RunHost").get_child_count() == 0, "RunHost retained children after five sessions.")
	_check(_records.size() == SESSION_COUNT, "Not all five session records were produced.")
	var victory_count: int = 0
	var defeat_count: int = 0
	for record: Dictionary in _records:
		if record.get("result", "") == "victory":
			victory_count += 1
		elif record.get("result", "") == "defeat":
			defeat_count += 1
		print("BALANCE SESSION: %s" % JSON.stringify(record))
	_check(victory_count == 4, "Expected four automated victories.")
	_check(defeat_count == 1, "Expected one automated defeat.")

	app.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.2).timeout
	var final_orphans: int = roundi(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check(
		final_orphans <= baseline_orphans,
		"Orphan node count grew from %d to %d." % [baseline_orphans, final_orphans]
	)
	_finish()


func _run_session(app: AppRoot, session_index: int, force_defeat: bool) -> void:
	_check(app.start_run(), "Session %d could not start." % (session_index + 1))
	await process_frame
	var arena: Node = app.get_current_run()
	_check(is_instance_valid(arena), "Session %d did not create an arena." % (session_index + 1))
	if not is_instance_valid(arena):
		return
	var director: RunDirector = arena.get_node("RunDirector") as RunDirector
	var waves: WaveDirector = arena.get_node("WaveDirector") as WaveDirector
	var encounter: BossEncounter = arena.get_node("BossEncounter") as BossEncounter
	var player: MagePlayer = arena.get_node("Player") as MagePlayer
	var metrics: RunMetricsRecorder = arena.get_node("RunMetricsRecorder") as RunMetricsRecorder
	metrics.metrics_path = "res://.godot/release_flow_metrics.jsonl"
	director.intermission_duration = 0.01
	_check(director.start_new_run(true), "Session %d could not reset." % (session_index + 1))
	await process_frame

	if force_defeat:
		player.get_health_component().take_damage(1000.0)
		await process_frame
		_check(director.current_state == RunDirector.State.DEFEAT, "Defeat flow did not reach DEFEAT.")
	else:
		player.get_hurtbox_component().grant_invulnerability(20.0)
		await _defeat_current_wave(waves)
		await _wait_for_wave(waves, 2)
		await _defeat_current_wave(waves)
		_check(director.current_state == RunDirector.State.UPGRADE, "Victory flow did not reach UPGRADE.")
		var options: Array[UpgradeData] = director.get_upgrade_options()
		var choice_index: int = session_index % maxi(1, options.size())
		_check(director.choose_upgrade(choice_index), "Victory flow could not choose an upgrade.")
		await process_frame
		var boss: ArenaWarden = encounter.get_boss()
		_check(is_instance_valid(boss), "Victory flow did not spawn the Arena Warden.")
		if is_instance_valid(boss):
			boss.get_health_component().take_damage(1000.0)
		await process_frame
		_check(director.current_state == RunDirector.State.VICTORY, "Boss defeat did not reach VICTORY.")

	var record: Dictionary = metrics.get_last_record()
	_check(not record.is_empty(), "Session %d did not produce local metrics." % (session_index + 1))
	if not record.is_empty():
		_records.append(record)
	_check(director.start_new_run(true), "Result restart failed in session %d." % (session_index + 1))
	await process_frame
	_check(player.get_health_component().is_alive(), "Restart did not restore the player.")
	app.return_to_menu()
	await process_frame
	await process_frame


func _defeat_current_wave(waves: WaveDirector) -> void:
	var expected: int = waves.get_remaining_count()
	for _frame: int in 240:
		if waves.get_spawned_enemies().size() == expected:
			break
		await physics_frame
	_check(waves.get_spawned_enemies().size() == expected, "A wave did not finish spawning within budget.")
	for enemy: Node in waves.get_spawned_enemies():
		if enemy is ChaserEnemy:
			(enemy as ChaserEnemy).get_health_component().take_damage(1000.0)
		elif enemy is CultistEnemy:
			(enemy as CultistEnemy).get_health_component().take_damage(1000.0)
	await process_frame


func _wait_for_wave(waves: WaveDirector, wave_number: int) -> void:
	for _frame: int in 120:
		if waves.is_wave_active() and waves.get_current_wave_number() == wave_number:
			return
		await physics_frame
	_check(false, "Wave %d did not start within budget." % wave_number)


func _check_settings_round_trip(app: AppRoot) -> void:
	var settings: SettingsStore = app.settings_store
	settings.settings_path = "res://.godot/release_flow_settings.cfg"
	settings.set_locale("en")
	settings.set_audio_levels(0.73, 0.61, 0.82)
	settings.set_graphics_quality(&"low")
	_check(settings.save_settings(), "Settings could not be saved during release flow.")
	settings.set_locale("ru")
	settings.set_audio_levels(0.2, 0.2, 0.2)
	_check(settings.load_settings(), "Settings could not be loaded during release flow.")
	settings.apply_all()
	_check(settings.locale == "en", "Locale did not survive the settings round-trip.")
	_check(is_equal_approx(settings.master_volume, 0.73), "Audio level did not survive settings round-trip.")
	settings.set_locale("ru")
	settings.set_graphics_quality(&"high")
	await process_frame
	var start_button: Button = app.get_node("ScreenHost/MainMenu/Center/Card/Content/Start") as Button
	_check(start_button.text == "Войти в Пепельную рощу", "Runtime localization did not refresh the main menu.")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("RELEASE FLOW TEST PASSED: five sessions, settings, restarts, menu, victory, defeat")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
