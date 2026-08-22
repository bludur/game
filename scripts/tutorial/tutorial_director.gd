class_name TutorialDirector
extends CanvasLayer

signal step_changed(step: int)
signal tutorial_completed()

enum Step {
	MOVE,
	CAST,
	SWITCH_SPELL,
	DASH,
	CHOOSE_UPGRADE,
	COMPLETE,
}

const SKIP_ACTION: StringName = &"tutorial_skip"

var current_step: Step = Step.MOVE
var _panel_tween: Tween

@onready var _panel: PanelContainer = get_node("Root/Panel") as PanelContainer
@onready var _progress_label: Label = get_node("Root/Panel/Content/Progress") as Label
@onready var _prompt_label: Label = get_node("Root/Panel/Content/Prompt") as Label
@onready var _skip_label: Label = get_node("Root/Panel/Content/Skip") as Label


func _ready() -> void:
	UiTranslations.ensure_registered()
	_ensure_skip_action()
	call_deferred("_bind_gameplay")
	_refresh_text()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(SKIP_ACTION):
		skip()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_text()


func notify_movement(is_moving: bool = true) -> void:
	if current_step == Step.MOVE and is_moving:
		_advance_to(Step.CAST)


func notify_cast(_spell: SpellData = null) -> void:
	if current_step == Step.CAST:
		_advance_to(Step.SWITCH_SPELL)


func notify_spell_switched(_spell: SpellData = null, slot_index: int = 1) -> void:
	if current_step == Step.SWITCH_SPELL and slot_index != 0:
		_advance_to(Step.DASH)


func notify_dash(_direction: Vector3 = Vector3.FORWARD) -> void:
	if current_step == Step.DASH:
		_advance_to(Step.CHOOSE_UPGRADE)


func notify_upgrade(_upgrade: UpgradeData = null) -> void:
	if current_step == Step.CHOOSE_UPGRADE:
		_advance_to(Step.COMPLETE)


func skip() -> void:
	if current_step != Step.COMPLETE:
		_advance_to(Step.COMPLETE)


func is_completed() -> bool:
	return current_step == Step.COMPLETE


func get_step_name() -> StringName:
	return StringName(Step.keys()[current_step].to_lower())


func _bind_gameplay() -> void:
	var player: MagePlayer = get_tree().get_first_node_in_group(&"player") as MagePlayer
	var director: RunDirector = get_tree().get_first_node_in_group(&"run_director") as RunDirector
	if not is_instance_valid(player) or not is_instance_valid(director):
		push_error("TutorialDirector requires MagePlayer and RunDirector.")
		return
	var controller: PlayerController = player.get_node("PlayerController") as PlayerController
	controller.movement_activity_changed.connect(notify_movement)
	player.get_spell_caster().spell_cast.connect(notify_cast)
	player.get_spell_loadout().active_spell_changed.connect(notify_spell_switched)
	player.get_dash_component().dash_started.connect(notify_dash)
	director.upgrade_applied.connect(notify_upgrade)


func _advance_to(next_step: Step) -> void:
	if next_step <= current_step:
		return
	current_step = next_step
	step_changed.emit(current_step)
	_refresh_text()
	if current_step == Step.COMPLETE:
		tutorial_completed.emit()
		_fade_out()
	else:
		_pulse_panel()


func _refresh_text() -> void:
	if not is_node_ready():
		return
	if current_step == Step.COMPLETE:
		_progress_label.text = tr("TUTORIAL_COMPLETE_TITLE")
		_prompt_label.text = tr("TUTORIAL_COMPLETE_PROMPT")
	else:
		_progress_label.text = tr("TUTORIAL_PROGRESS") % [current_step + 1, Step.COMPLETE]
		_prompt_label.text = tr(_prompt_key(current_step))
	_skip_label.text = tr("TUTORIAL_SKIP")


func _prompt_key(step: Step) -> StringName:
	match step:
		Step.MOVE:
			return &"TUTORIAL_MOVE"
		Step.CAST:
			return &"TUTORIAL_CAST"
		Step.SWITCH_SPELL:
			return &"TUTORIAL_SWITCH"
		Step.DASH:
			return &"TUTORIAL_DASH"
		Step.CHOOSE_UPGRADE:
			return &"TUTORIAL_UPGRADE"
		_:
			return &"TUTORIAL_COMPLETE_PROMPT"


func _pulse_panel() -> void:
	if _panel_tween != null:
		_panel_tween.kill()
	_panel.modulate = Color(1.0, 1.0, 1.0, 0.35)
	_panel.scale = Vector2(0.98, 0.98)
	_panel.pivot_offset = _panel.size * 0.5
	_panel_tween = create_tween().set_parallel(true)
	_panel_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_panel_tween.tween_property(_panel, "modulate", Color.WHITE, 0.22)
	_panel_tween.tween_property(_panel, "scale", Vector2.ONE, 0.22)


func _fade_out() -> void:
	if _panel_tween != null:
		_panel_tween.kill()
	_panel_tween = create_tween()
	_panel_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_panel_tween.tween_interval(1.2)
	_panel_tween.tween_property(_panel, "modulate:a", 0.0, 0.45)
	_panel_tween.tween_callback(_panel.hide)


func _ensure_skip_action() -> void:
	if InputMap.has_action(SKIP_ACTION):
		return
	InputMap.add_action(SKIP_ACTION)
	var key_event: InputEventKey = InputEventKey.new()
	key_event.physical_keycode = KEY_F1
	InputMap.action_add_event(SKIP_ACTION, key_event)
	var joy_event: InputEventJoypadButton = InputEventJoypadButton.new()
	joy_event.button_index = JOY_BUTTON_BACK
	InputMap.action_add_event(SKIP_ACTION, joy_event)
