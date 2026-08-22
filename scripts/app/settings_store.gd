class_name SettingsStore
extends Node

signal settings_changed()
signal binding_conflict_resolved(action: StringName)

const SCHEMA_VERSION: int = 3
const MIN_SUPPORTED_SCHEMA_VERSION: int = 1
const DEFAULT_PATH: String = "user://settings.cfg"
const SUPPORTED_LOCALES: PackedStringArray = ["ru", "en"]

@export var settings_path: String = DEFAULT_PATH

var master_volume: float = 0.8
var music_volume: float = 0.72
var sfx_volume: float = 0.82
var window_mode: StringName = &"windowed"
var graphics_quality: StringName = &"high"
var locale: String = "ru"
var ui_scale: float = 1.0
var flash_intensity: float = 0.7
var screen_shake_enabled: bool = true
var hold_to_interact: bool = false
var mouse_sensitivity: float = 0.003
var invert_camera_y: bool = false
var camera_fov: float = 70.0
var left_shoulder_camera: bool = false
var _default_bindings: Dictionary[StringName, Array] = {}


func _ready() -> void:
	_install_translations()
	_ensure_gamepad_actions()
	_capture_default_bindings()
	load_settings()
	apply_all()


func load_settings() -> bool:
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(settings_path)
	if error != OK:
		_reset_values()
		return false
	var version: int = int(config.get_value("meta", "version", 0))
	if version < MIN_SUPPORTED_SCHEMA_VERSION or version > SCHEMA_VERSION:
		_reset_values()
		return false
	master_volume = clampf(float(config.get_value("audio", "master", 0.8)), 0.0, 1.0)
	music_volume = clampf(float(config.get_value("audio", "music", 0.72)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value("audio", "sfx", 0.82)), 0.0, 1.0)
	window_mode = _sanitize_choice(
		StringName(config.get_value("video", "window_mode", "windowed")),
		[&"windowed", &"fullscreen"],
		&"windowed"
	)
	graphics_quality = _sanitize_choice(
		StringName(config.get_value("video", "graphics_quality", "high")),
		[&"low", &"high"],
		&"high"
	)
	locale = String(config.get_value("general", "locale", "ru"))
	if not SUPPORTED_LOCALES.has(locale):
		locale = "ru"
	ui_scale = clampf(float(config.get_value("accessibility", "ui_scale", 1.0)), 0.8, 1.4)
	flash_intensity = clampf(float(config.get_value("accessibility", "flash_intensity", 0.7)), 0.0, 1.0)
	screen_shake_enabled = bool(config.get_value("accessibility", "screen_shake_enabled", true))
	hold_to_interact = bool(config.get_value("accessibility", "hold_to_interact", false))
	mouse_sensitivity = clampf(float(config.get_value("camera", "mouse_sensitivity", 0.003)), 0.0005, 0.02)
	invert_camera_y = bool(config.get_value("camera", "invert_y", false))
	camera_fov = clampf(float(config.get_value("camera", "field_of_view", 70.0)), 50.0, 100.0)
	left_shoulder_camera = bool(config.get_value("camera", "left_shoulder", false))
	_load_bindings(config)
	return true


func save_settings() -> bool:
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(settings_path.get_base_dir())
	)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		push_error("Could not create settings directory: %s" % directory_error)
		return false
	var config: ConfigFile = ConfigFile.new()
	config.set_value("meta", "version", SCHEMA_VERSION)
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("video", "window_mode", String(window_mode))
	config.set_value("video", "graphics_quality", String(graphics_quality))
	config.set_value("general", "locale", locale)
	config.set_value("accessibility", "ui_scale", ui_scale)
	config.set_value("accessibility", "flash_intensity", flash_intensity)
	config.set_value("accessibility", "screen_shake_enabled", screen_shake_enabled)
	config.set_value("accessibility", "hold_to_interact", hold_to_interact)
	config.set_value("camera", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("camera", "invert_y", invert_camera_y)
	config.set_value("camera", "field_of_view", camera_fov)
	config.set_value("camera", "left_shoulder", left_shoulder_camera)
	for action: StringName in _default_bindings:
		var serialized: Array[Dictionary] = []
		for event: InputEvent in InputMap.action_get_events(action):
			var data: Dictionary = _serialize_event(event)
			if not data.is_empty():
				serialized.append(data)
		config.set_value("bindings", String(action), serialized)
	var error: Error = config.save(settings_path)
	if error != OK:
		push_error("Could not save settings: %s" % error)
	return error == OK


func set_audio_levels(master: float, music: float, sfx: float) -> void:
	master_volume = clampf(master, 0.0, 1.0)
	music_volume = clampf(music, 0.0, 1.0)
	sfx_volume = clampf(sfx, 0.0, 1.0)
	_apply_audio()
	settings_changed.emit()


func set_locale(locale_code: String) -> void:
	locale = locale_code if SUPPORTED_LOCALES.has(locale_code) else "ru"
	TranslationServer.set_locale(locale)
	settings_changed.emit()


func set_window_mode(mode: StringName) -> void:
	window_mode = _sanitize_choice(mode, [&"windowed", &"fullscreen"], &"windowed")
	_apply_window_mode()
	settings_changed.emit()


func set_graphics_quality(quality: StringName) -> void:
	graphics_quality = _sanitize_choice(quality, [&"low", &"high"], &"high")
	_apply_graphics()
	settings_changed.emit()


func set_accessibility(
	next_ui_scale: float,
	next_flash_intensity: float,
	next_screen_shake_enabled: bool,
	next_hold_to_interact: bool
) -> void:
	ui_scale = clampf(next_ui_scale, 0.8, 1.4)
	flash_intensity = clampf(next_flash_intensity, 0.0, 1.0)
	screen_shake_enabled = next_screen_shake_enabled
	hold_to_interact = next_hold_to_interact
	_apply_accessibility()
	settings_changed.emit()


func set_camera_preferences(
	next_mouse_sensitivity: float,
	next_invert_y: bool,
	next_fov: float,
	next_left_shoulder: bool
) -> void:
	mouse_sensitivity = clampf(next_mouse_sensitivity, 0.0005, 0.02)
	invert_camera_y = next_invert_y
	camera_fov = clampf(next_fov, 50.0, 100.0)
	left_shoulder_camera = next_left_shoulder
	_apply_camera_preferences()
	settings_changed.emit()


func rebind_action(action: StringName, event: InputEvent) -> bool:
	if not _default_bindings.has(action) or event == null:
		return false
	var conflict: StringName
	for other_action: StringName in _default_bindings:
		if other_action == action:
			continue
		for other_event: InputEvent in InputMap.action_get_events(other_action):
			if other_event.as_text() == event.as_text():
				conflict = other_action
				InputMap.action_erase_event(other_action, other_event)
				break
		if conflict != &"":
			break
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	if conflict != &"":
		binding_conflict_resolved.emit(conflict)
	settings_changed.emit()
	return true


func reset_input_bindings() -> void:
	for action: StringName in _default_bindings:
		InputMap.action_erase_events(action)
		for event: InputEvent in _default_bindings[action]:
			InputMap.action_add_event(action, event.duplicate(true) as InputEvent)
	settings_changed.emit()


func apply_all() -> void:
	_apply_audio()
	_apply_window_mode()
	_apply_graphics()
	_apply_accessibility()
	_apply_camera_preferences()
	TranslationServer.set_locale(locale)


func _reset_values() -> void:
	master_volume = 0.8
	music_volume = 0.72
	sfx_volume = 0.82
	window_mode = &"windowed"
	graphics_quality = &"high"
	locale = "ru"
	ui_scale = 1.0
	flash_intensity = 0.7
	screen_shake_enabled = true
	hold_to_interact = false
	mouse_sensitivity = 0.003
	invert_camera_y = false
	camera_fov = 70.0
	left_shoulder_camera = false


func _apply_audio() -> void:
	_set_bus_volume(&"Master", master_volume)
	_set_bus_volume(&"Music", music_volume)
	_set_bus_volume(&"SFX", sfx_volume)


func _set_bus_volume(bus: StringName, linear_value: float) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear_value, 0.0001)))


func _apply_window_mode() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN \
		if window_mode == &"fullscreen" else DisplayServer.WINDOW_MODE_WINDOWED
	)


func _apply_graphics() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X if graphics_quality == &"high" else Viewport.MSAA_DISABLED


func _apply_accessibility() -> void:
	get_tree().root.content_scale_factor = ui_scale
	ProjectSettings.set_setting("witchroot/accessibility/flash_intensity", flash_intensity)
	ProjectSettings.set_setting("witchroot/accessibility/screen_shake_enabled", screen_shake_enabled)
	ProjectSettings.set_setting("witchroot/accessibility/hold_to_interact", hold_to_interact)


func _apply_camera_preferences() -> void:
	ProjectSettings.set_setting("witchroot/camera/mouse_sensitivity", mouse_sensitivity)
	ProjectSettings.set_setting("witchroot/camera/invert_y", invert_camera_y)
	ProjectSettings.set_setting("witchroot/camera/field_of_view", camera_fov)
	ProjectSettings.set_setting("witchroot/camera/left_shoulder", left_shoulder_camera)


func _sanitize_choice(value: StringName, allowed: Array[StringName], fallback: StringName) -> StringName:
	return value if allowed.has(value) else fallback


func _capture_default_bindings() -> void:
	for action: StringName in [
		&"move_forward", &"move_backward", &"move_left", &"move_right",
		&"primary_spell", &"dash", &"jump", &"sprint", &"spell_slot_1", &"spell_slot_2",
		&"spell_slot_3", &"pause", &"aim_left", &"aim_right", &"aim_up", &"aim_down",
		&"camera_swap_shoulder",
	]:
		if not InputMap.has_action(action):
			continue
		var events: Array[InputEvent] = []
		for event: InputEvent in InputMap.action_get_events(action):
			events.append(event.duplicate(true) as InputEvent)
		_default_bindings[action] = events


func _ensure_gamepad_actions() -> void:
	_add_joy_axis(&"move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis(&"move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis(&"move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis(&"move_backward", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_axis(&"aim_left", JOY_AXIS_RIGHT_X, -1.0)
	_add_joy_axis(&"aim_right", JOY_AXIS_RIGHT_X, 1.0)
	_add_joy_axis(&"aim_up", JOY_AXIS_RIGHT_Y, -1.0)
	_add_joy_axis(&"aim_down", JOY_AXIS_RIGHT_Y, 1.0)
	_add_joy_button(&"primary_spell", JOY_BUTTON_RIGHT_SHOULDER)
	_add_joy_button(&"dash", JOY_BUTTON_B)
	_add_joy_button(&"jump", JOY_BUTTON_A)
	_add_joy_button(&"sprint", JOY_BUTTON_LEFT_STICK)
	_add_joy_button(&"pause", JOY_BUTTON_START)


func _add_joy_axis(action: StringName, axis: JoyAxis, value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	if not _action_has_event(action, event):
		InputMap.action_add_event(action, event)


func _add_joy_button(action: StringName, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button
	if not _action_has_event(action, event):
		InputMap.action_add_event(action, event)


func _action_has_event(action: StringName, candidate: InputEvent) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event.as_text() == candidate.as_text():
			return true
	return false


func _serialize_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"type": "key", "code": (event as InputEventKey).physical_keycode}
	if event is InputEventMouseButton:
		return {"type": "mouse", "button": (event as InputEventMouseButton).button_index}
	if event is InputEventJoypadButton:
		return {"type": "joy_button", "button": (event as InputEventJoypadButton).button_index}
	if event is InputEventJoypadMotion:
		return {
			"type": "joy_axis",
			"axis": (event as InputEventJoypadMotion).axis,
			"value": (event as InputEventJoypadMotion).axis_value,
		}
	return {}


func _load_bindings(config: ConfigFile) -> void:
	for action: StringName in _default_bindings:
		var records: Variant = config.get_value("bindings", String(action), null)
		if records is not Array:
			continue
		var loaded_events: Array[InputEvent] = []
		for record: Variant in records as Array:
			if record is Dictionary:
				var event: InputEvent = _deserialize_event(record as Dictionary)
				if event != null:
					loaded_events.append(event)
		if loaded_events.is_empty():
			continue
		InputMap.action_erase_events(action)
		for event: InputEvent in loaded_events:
			InputMap.action_add_event(action, event)


func _deserialize_event(data: Dictionary) -> InputEvent:
	match String(data.get("type", "")):
		"key":
			var key: InputEventKey = InputEventKey.new()
			key.physical_keycode = int(data.get("code", 0)) as Key
			return key
		"mouse":
			var mouse: InputEventMouseButton = InputEventMouseButton.new()
			mouse.button_index = int(data.get("button", 1)) as MouseButton
			return mouse
		"joy_button":
			var button: InputEventJoypadButton = InputEventJoypadButton.new()
			button.button_index = int(data.get("button", 0)) as JoyButton
			return button
		"joy_axis":
			var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
			motion.axis = int(data.get("axis", 0)) as JoyAxis
			motion.axis_value = float(data.get("value", 1.0))
			return motion
		_:
			return null


func _install_translations() -> void:
	UiTranslations.ensure_registered()
	_register_translation("en", {
		"GAME_TITLE": "Witchroot",
		"GAME_SUBTITLE": "MAGICAL DARK-FANTASY SURVIVAL",
		"MENU_START": "Enter the Ashen Grove", "MENU_SETTINGS": "Settings", "MENU_QUIT": "Quit",
		"MENU_RESUME": "Resume", "MENU_MAIN": "Main Menu", "MENU_BACK": "Back",
		"SETTINGS_TITLE": "Settings", "SETTINGS_MASTER": "Master Volume",
		"SETTINGS_MUSIC": "Music", "SETTINGS_SFX": "Sound Effects",
		"SETTINGS_LANGUAGE": "Language", "SETTINGS_WINDOW": "Window Mode",
		"SETTINGS_GRAPHICS": "Graphics", "SETTINGS_REBIND_CAST": "Rebind Cast",
		"SETTINGS_REBIND_DASH": "Rebind Dash", "SETTINGS_RESET": "Reset Controls",
		"SETTINGS_UI_SCALE": "Interface Scale", "SETTINGS_FLASH": "Flash Intensity",
		"SETTINGS_SHAKE": "Screen Shake", "SETTINGS_HOLD_INTERACT": "Hold to Interact",
		"SETTINGS_CAMERA_SENSITIVITY": "Camera Sensitivity", "SETTINGS_CAMERA_FOV": "Field of View",
		"SETTINGS_INVERT_Y": "Invert Camera Y", "SETTINGS_LEFT_SHOULDER": "Default to Left Shoulder",
		"SETTINGS_SAVE": "Save and Back", "SETTINGS_PRESS_INPUT": "Press a key or gamepad button…",
		"WINDOWED": "Windowed", "FULLSCREEN": "Fullscreen", "QUALITY_LOW": "Low", "QUALITY_HIGH": "High",
		"PAUSED": "Paused", "RESULT_MENU": "Return to Main Menu",
	})
	_register_translation("ru", {
		"GAME_TITLE": "Witchroot",
		"GAME_SUBTITLE": "МАГИЧЕСКОЕ ВЫЖИВАНИЕ В ТЁМНОМ ФЭНТЕЗИ",
		"MENU_START": "Войти в Пепельную рощу", "MENU_SETTINGS": "Настройки", "MENU_QUIT": "Выход",
		"MENU_RESUME": "Продолжить", "MENU_MAIN": "Главное меню", "MENU_BACK": "Назад",
		"SETTINGS_TITLE": "Настройки", "SETTINGS_MASTER": "Общая громкость",
		"SETTINGS_MUSIC": "Музыка", "SETTINGS_SFX": "Эффекты",
		"SETTINGS_LANGUAGE": "Язык", "SETTINGS_WINDOW": "Режим окна",
		"SETTINGS_GRAPHICS": "Графика", "SETTINGS_REBIND_CAST": "Назначить атаку",
		"SETTINGS_REBIND_DASH": "Назначить рывок", "SETTINGS_RESET": "Сбросить управление",
		"SETTINGS_UI_SCALE": "Масштаб интерфейса", "SETTINGS_FLASH": "Интенсивность вспышек",
		"SETTINGS_SHAKE": "Тряска экрана", "SETTINGS_HOLD_INTERACT": "Удерживать для взаимодействия",
		"SETTINGS_CAMERA_SENSITIVITY": "Чувствительность камеры", "SETTINGS_CAMERA_FOV": "Угол обзора",
		"SETTINGS_INVERT_Y": "Инверсия камеры по Y", "SETTINGS_LEFT_SHOULDER": "Камера у левого плеча",
		"SETTINGS_SAVE": "Сохранить и назад", "SETTINGS_PRESS_INPUT": "Нажмите клавишу или кнопку геймпада…",
		"WINDOWED": "В окне", "FULLSCREEN": "Полный экран", "QUALITY_LOW": "Низко", "QUALITY_HIGH": "Высоко",
		"PAUSED": "Пауза", "RESULT_MENU": "Вернуться в главное меню",
	})


func _register_translation(locale_code: String, messages: Dictionary) -> void:
	var translation: Translation = Translation.new()
	translation.locale = locale_code
	for key: String in messages:
		translation.add_message(StringName(key), String(messages[key]))
	TranslationServer.add_translation(translation)
