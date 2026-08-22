class_name SurvivalInputProfile
extends RefCounted

static var _legacy_dash_migrated: bool = false


static func ensure_actions() -> void:
	if not _legacy_dash_migrated:
		_migrate_dash_binding()
		_legacy_dash_migrated = true
	_add_key_action(&"jump", KEY_SPACE, JOY_BUTTON_A)
	_add_key_action(&"sprint", KEY_SHIFT, JOY_BUTTON_LEFT_STICK)
	_add_mouse_joy_axis_action(&"ward", MOUSE_BUTTON_RIGHT, JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add_key_action(&"interact", KEY_E, JOY_BUTTON_A)
	_add_key_action(&"inventory", KEY_TAB, JOY_BUTTON_BACK)
	_add_key_action(&"crafting", KEY_C, JOY_BUTTON_Y)
	_add_key_action(&"ritual", KEY_R, JOY_BUTTON_X)
	_add_key_action(&"build_mode", KEY_B, JOY_BUTTON_LEFT_SHOULDER)
	_add_key_action(&"use_consumable", KEY_X, JOY_BUTTON_DPAD_DOWN)
	_add_key_action(&"quick_save", KEY_F5, JOY_BUTTON_START)
	_add_key_action(&"region_map", KEY_M, JOY_BUTTON_RIGHT_STICK)
	_add_key_action(&"camera_rotate_left", KEY_Q, JOY_BUTTON_DPAD_LEFT)
	_add_key_action(&"camera_rotate_right", KEY_T, JOY_BUTTON_DPAD_RIGHT)
	_add_key_action(&"camera_swap_shoulder", KEY_V, JOY_BUTTON_DPAD_UP)
	_add_mouse_action(&"camera_zoom_in", MOUSE_BUTTON_WHEEL_UP)
	_add_mouse_action(&"camera_zoom_out", MOUSE_BUTTON_WHEEL_DOWN)
	_add_joy_axis_action(&"aim_left", JOY_AXIS_RIGHT_X, -1.0)
	_add_joy_axis_action(&"aim_right", JOY_AXIS_RIGHT_X, 1.0)
	_add_joy_axis_action(&"aim_up", JOY_AXIS_RIGHT_Y, -1.0)
	_add_joy_axis_action(&"aim_down", JOY_AXIS_RIGHT_Y, 1.0)


static func _migrate_dash_binding() -> void:
	if not InputMap.has_action(&"dash"):
		_add_key_action(&"dash", KEY_ALT, JOY_BUTTON_B)
		return
	var replaced_legacy_binding: bool = false
	for input_event: InputEvent in InputMap.action_get_events(&"dash"):
		if input_event is InputEventKey \
				and ((input_event as InputEventKey).physical_keycode == KEY_SHIFT \
				or (input_event as InputEventKey).physical_keycode == KEY_SPACE):
			InputMap.action_erase_event(&"dash", input_event)
			replaced_legacy_binding = true
		elif input_event is InputEventJoypadButton \
				and (input_event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
			InputMap.action_erase_event(&"dash", input_event)
			replaced_legacy_binding = true
	if replaced_legacy_binding or not _has_keyboard_binding(&"dash"):
		_add_key_event(&"dash", KEY_ALT)
	_add_joy_button_event(&"dash", JOY_BUTTON_B)


static func _has_keyboard_binding(action: StringName) -> bool:
	for input_event: InputEvent in InputMap.action_get_events(action):
		if input_event is InputEventKey:
			return true
	return false


static func _add_key_event(action: StringName, key: Key) -> void:
	var key_event: InputEventKey = InputEventKey.new()
	key_event.physical_keycode = key
	if not _action_has_event(action, key_event):
		InputMap.action_add_event(action, key_event)


static func _add_joy_button_event(action: StringName, button: JoyButton) -> void:
	var joy_event: InputEventJoypadButton = InputEventJoypadButton.new()
	joy_event.button_index = button
	if not _action_has_event(action, joy_event):
		InputMap.action_add_event(action, joy_event)


static func _add_key_action(action: StringName, key: Key, joy_button: JoyButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.2)
	var key_event: InputEventKey = InputEventKey.new()
	key_event.physical_keycode = key
	InputMap.action_add_event(action, key_event)
	var joy_event: InputEventJoypadButton = InputEventJoypadButton.new()
	joy_event.button_index = joy_button
	InputMap.action_add_event(action, joy_event)


static func _add_mouse_action(action: StringName, button: MouseButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.2)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)


static func _add_mouse_joy_axis_action(
	action: StringName,
	button: MouseButton,
	axis: JoyAxis,
	axis_value: float
) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
	mouse_event.button_index = button
	if not _action_has_event(action, mouse_event):
		InputMap.action_add_event(action, mouse_event)
	var joy_event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	joy_event.axis = axis
	joy_event.axis_value = axis_value
	if not _action_has_event(action, joy_event):
		InputMap.action_add_event(action, joy_event)


static func _add_joy_axis_action(action: StringName, axis: JoyAxis, value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	if not _action_has_event(action, event):
		InputMap.action_add_event(action, event)


static func _action_has_event(action: StringName, candidate: InputEvent) -> bool:
	for input_event: InputEvent in InputMap.action_get_events(action):
		if input_event.as_text() == candidate.as_text():
			return true
	return false
