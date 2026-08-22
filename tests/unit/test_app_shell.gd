extends GutTest

const APP_SCENE: PackedScene = preload("res://scenes/main/main.tscn")


func after_each() -> void:
	get_tree().paused = false


func test_app_transitions_menu_run_pause_and_back_without_accumulation() -> void:
	var app: AppRoot = APP_SCENE.instantiate() as AppRoot
	add_child_autofree(app)
	await get_tree().process_frame
	assert_null(app.get_current_run())
	assert_true((app.get_node("ScreenHost/MainMenu") as Control).visible)
	for _cycle: int in 3:
		assert_true(app.start_run())
		await get_tree().process_frame
		assert_not_null(app.get_current_run())
		assert_eq(app.get_node("RunHost").get_child_count(), 1)
		app.toggle_pause()
		assert_true(get_tree().paused)
		assert_true((app.get_node("PauseMenu") as PauseMenu).is_open())
		app.toggle_pause()
		assert_false(get_tree().paused)
		app.return_to_menu()
		await get_tree().process_frame
		assert_null(app.get_current_run())
		assert_eq(app.get_node("RunHost").get_child_count(), 0)


func test_language_switch_updates_semantic_menu_keys() -> void:
	var app: AppRoot = APP_SCENE.instantiate() as AppRoot
	add_child_autofree(app)
	await get_tree().process_frame
	app.settings_store.set_locale("ru")
	await get_tree().process_frame
	var start_button: Button = app.get_node("ScreenHost/MainMenu/Center/Card/Content/Start") as Button
	assert_eq(start_button.text, "Войти в Пепельную рощу")
	app.settings_store.set_locale("en")
	await get_tree().process_frame
	assert_eq(start_button.text, "Enter the Ashen Grove")


func test_shell_controls_use_full_rect_anchors_and_large_targets() -> void:
	var app: AppRoot = APP_SCENE.instantiate() as AppRoot
	add_child_autofree(app)
	await get_tree().process_frame
	var screen_host: Control = app.get_node("ScreenHost") as Control
	var menu: Control = app.get_node("ScreenHost/MainMenu") as Control
	var start_button: Button = app.get_node("ScreenHost/MainMenu/Center/Card/Content/Start") as Button
	assert_eq(screen_host.anchor_right, 1.0)
	assert_eq(screen_host.anchor_bottom, 1.0)
	assert_eq(menu.anchor_right, 1.0)
	assert_gte(start_button.custom_minimum_size.y, 44.0)


func test_settings_remain_scrollable_at_reference_resolution() -> void:
	var app: AppRoot = APP_SCENE.instantiate() as AppRoot
	add_child_autofree(app)
	await get_tree().process_frame
	var settings: SettingsMenu = app.get_node("ScreenHost/SettingsMenu") as SettingsMenu
	settings.visible = true
	await get_tree().process_frame
	var scroll: ScrollContainer = settings.get_node("Center/Card/Scroll") as ScrollContainer
	var subtitles: CheckButton = settings.get_node("Center/Card/Scroll/Content/Subtitles") as CheckButton
	assert_lte(scroll.size.y, 640.0)
	assert_gt(scroll.get_v_scroll_bar().max_value, scroll.size.y)
	assert_gte(subtitles.custom_minimum_size.y, 42.0)


func test_survival_hud_refreshes_glyph_after_runtime_remapping() -> void:
	var app: AppRoot = APP_SCENE.instantiate() as AppRoot
	add_child_autofree(app)
	await get_tree().process_frame
	assert_true(app.start_survival())
	await get_tree().process_frame
	var session: WorldSession = app.get_current_run() as WorldSession
	var hotkeys: Label = session.survival_hud.get_node("Root/Hotkeys") as Label
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_K
	assert_true(app.settings_store.rebind_action(&"primary_spell", key))
	assert_true(hotkeys.text.contains("K"))
	app.settings_store.reset_input_bindings()
