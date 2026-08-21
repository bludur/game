class_name SpellLoadout
extends Node

signal active_spell_changed(spell: SpellData, slot_index: int)

const SLOT_ONE_ACTION: StringName = &"spell_slot_1"
const SLOT_TWO_ACTION: StringName = &"spell_slot_2"

@export var primary_spell: SpellData
@export var secondary_spell: SpellData

var active_slot_index: int = 0
var _caster: SpellCaster
var _enabled: bool = true


func _ready() -> void:
	_ensure_input_action(SLOT_ONE_ACTION, KEY_1, JOY_BUTTON_DPAD_LEFT)
	_ensure_input_action(SLOT_TWO_ACTION, KEY_2, JOY_BUTTON_DPAD_RIGHT)


func bind(caster: SpellCaster) -> void:
	_caster = caster
	select_slot(active_slot_index)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	set_process_unhandled_input(enabled)


func select_slot(slot_index: int) -> bool:
	var selected_spell: SpellData = get_spell(slot_index)
	if selected_spell == null or not selected_spell.is_valid_definition():
		return false
	active_slot_index = slot_index
	if is_instance_valid(_caster):
		_caster.set_spell(selected_spell)
	active_spell_changed.emit(selected_spell, active_slot_index)
	return true


func get_active_spell() -> SpellData:
	return get_spell(active_slot_index)


func get_spell(slot_index: int) -> SpellData:
	match slot_index:
		0:
			return primary_spell
		1:
			return secondary_spell
		_:
			return null


func set_spell(slot_index: int, spell: SpellData) -> bool:
	if spell == null or not spell.is_valid_definition():
		return false
	match slot_index:
		0:
			primary_spell = spell
		1:
			secondary_spell = spell
		_:
			return false
	if active_slot_index == slot_index:
		select_slot(slot_index)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event.is_action_pressed(SLOT_ONE_ACTION):
		select_slot(0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(SLOT_TWO_ACTION):
		select_slot(1)
		get_viewport().set_input_as_handled()


func _ensure_input_action(action: StringName, keycode: Key, joy_button: JoyButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.2)
	var key_event: InputEventKey = InputEventKey.new()
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action, key_event)
	var joy_event: InputEventJoypadButton = InputEventJoypadButton.new()
	joy_event.button_index = joy_button
	InputMap.action_add_event(action, joy_event)
