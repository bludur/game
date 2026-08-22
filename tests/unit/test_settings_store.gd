extends GutTest

const TEST_PATH: String = "res://.godot/settings_store_test.cfg"


func before_each() -> void:
	_remove_test_file()


func after_each() -> void:
	_remove_test_file()


func test_settings_round_trip_with_schema_version_and_safe_values() -> void:
	var store: SettingsStore = _create_store()
	store.set_audio_levels(0.45, 0.55, 0.65)
	store.set_locale("en")
	store.set_graphics_quality(&"low")
	store.set_accessibility(1.2, 0.3, false, true)
	store.set_camera_preferences(0.006, true, 82.0, true)
	assert_true(store.save_settings())
	store.queue_free()
	await get_tree().process_frame

	var loaded: SettingsStore = _create_store()
	assert_eq(loaded.master_volume, 0.45)
	assert_eq(loaded.music_volume, 0.55)
	assert_eq(loaded.sfx_volume, 0.65)
	assert_eq(loaded.locale, "en")
	assert_eq(loaded.graphics_quality, &"low")
	assert_eq(loaded.ui_scale, 1.2)
	assert_eq(loaded.flash_intensity, 0.3)
	assert_false(loaded.screen_shake_enabled)
	assert_true(loaded.hold_to_interact)
	assert_almost_eq(loaded.mouse_sensitivity, 0.006, 0.0001)
	assert_true(loaded.invert_camera_y)
	assert_almost_eq(loaded.camera_fov, 82.0, 0.001)
	assert_true(loaded.left_shoulder_camera)


func test_unknown_schema_falls_back_to_defaults() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("meta", "version", 999)
	config.set_value("audio", "master", -100.0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_PATH.get_base_dir()))
	assert_eq(config.save(TEST_PATH), OK)
	var store: SettingsStore = _create_store()
	assert_eq(store.master_volume, 0.8)
	assert_eq(store.locale, "ru")
	assert_eq(store.window_mode, &"windowed")


func test_rebinding_resolves_conflict_and_reset_restores_defaults() -> void:
	var store: SettingsStore = _create_store()
	var conflicts: Array[StringName] = []
	store.binding_conflict_resolved.connect(
		func(action: StringName) -> void: conflicts.append(action)
	)
	var shared_key: InputEventKey = InputEventKey.new()
	shared_key.physical_keycode = KEY_K
	assert_true(store.rebind_action(&"primary_spell", shared_key))
	assert_true(store.rebind_action(&"dash", shared_key.duplicate(true) as InputEvent))
	assert_eq(conflicts, [&"primary_spell"])
	assert_true(InputMap.action_get_events(&"primary_spell").is_empty())
	store.reset_input_bindings()
	assert_false(InputMap.action_get_events(&"primary_spell").is_empty())


func _create_store() -> SettingsStore:
	var store: SettingsStore = SettingsStore.new()
	store.settings_path = TEST_PATH
	add_child_autofree(store)
	return store


func _remove_test_file() -> void:
	var absolute_path: String = ProjectSettings.globalize_path(TEST_PATH)
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(absolute_path)
