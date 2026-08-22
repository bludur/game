class_name InputGlyphs
extends RefCounted


static func action_label(action: StringName, gamepad: bool) -> String:
	for event: InputEvent in InputMap.action_get_events(action):
		if gamepad and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
			return _gamepad_label(event)
		if not gamepad and (event is InputEventKey or event is InputEventMouseButton):
			return _desktop_label(event)
	return "?"


static func movement_label(gamepad: bool) -> String:
	return "LS" if gamepad else "WASD"


static func camera_label(gamepad: bool) -> String:
	return "RS" if gamepad else "Mouse"


static func _desktop_label(event: InputEvent) -> String:
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return OS.get_keycode_string(code)
	if event is InputEventMouseButton:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				return "LMB"
			MOUSE_BUTTON_RIGHT:
				return "RMB"
			MOUSE_BUTTON_MIDDLE:
				return "MMB"
			_:
				return "Mouse %d" % (event as InputEventMouseButton).button_index
	return "?"


static func _gamepad_label(event: InputEvent) -> String:
	if event is InputEventJoypadMotion:
		match (event as InputEventJoypadMotion).axis:
			JOY_AXIS_TRIGGER_LEFT:
				return "LT"
			JOY_AXIS_TRIGGER_RIGHT:
				return "RT"
			JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y:
				return "LS"
			JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y:
				return "RS"
			_:
				return "Axis"
	match (event as InputEventJoypadButton).button_index:
		JOY_BUTTON_A:
			return "A"
		JOY_BUTTON_B:
			return "B"
		JOY_BUTTON_X:
			return "X"
		JOY_BUTTON_Y:
			return "Y"
		JOY_BUTTON_LEFT_SHOULDER:
			return "LB"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "RB"
		JOY_BUTTON_LEFT_STICK:
			return "LS"
		JOY_BUTTON_RIGHT_STICK:
			return "RS"
		JOY_BUTTON_BACK:
			return "BACK"
		JOY_BUTTON_START:
			return "START"
		JOY_BUTTON_DPAD_UP:
			return "D↑"
		JOY_BUTTON_DPAD_DOWN:
			return "D↓"
		JOY_BUTTON_DPAD_LEFT:
			return "D←"
		JOY_BUTTON_DPAD_RIGHT:
			return "D→"
		_:
			return "Pad %d" % (event as InputEventJoypadButton).button_index
