class_name SurvivalInputProfile
extends RefCounted


static func ensure_actions() -> void:
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
	_add_mouse_action(&"camera_zoom_in", MOUSE_BUTTON_WHEEL_UP)
	_add_mouse_action(&"camera_zoom_out", MOUSE_BUTTON_WHEEL_DOWN)


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
