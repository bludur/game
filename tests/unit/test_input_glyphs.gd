extends GutTest

const INPUT_GLYPHS: Script = preload("res://scripts/app/input_glyphs.gd")


func test_default_desktop_and_gamepad_glyphs_match_input_map() -> void:
	SurvivalInputProfile.ensure_actions()
	assert_eq(INPUT_GLYPHS.action_label(&"interact", false), "E")
	assert_eq(INPUT_GLYPHS.action_label(&"interact", true), "A")
	assert_eq(INPUT_GLYPHS.action_label(&"primary_spell", false), "LMB")
	assert_eq(INPUT_GLYPHS.action_label(&"ward", true), "LT")
	assert_eq(INPUT_GLYPHS.movement_label(false), "WASD")
	assert_eq(INPUT_GLYPHS.camera_label(true), "RS")


func test_glyph_reflects_runtime_remapping() -> void:
	SurvivalInputProfile.ensure_actions()
	var original_events: Array[InputEvent] = []
	for event: InputEvent in InputMap.action_get_events(&"primary_spell"):
		original_events.append(event.duplicate(true) as InputEvent)
	InputMap.action_erase_events(&"primary_spell")
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_K
	InputMap.action_add_event(&"primary_spell", key)
	assert_eq(INPUT_GLYPHS.action_label(&"primary_spell", false), "K")
	InputMap.action_erase_events(&"primary_spell")
	for event: InputEvent in original_events:
		InputMap.action_add_event(&"primary_spell", event)
