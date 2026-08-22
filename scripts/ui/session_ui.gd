class_name SessionUi
extends CanvasLayer

var _run_director: RunDirector
var _upgrade_options: Array[UpgradeData] = []

@onready var _announcement: PanelContainer = get_node("Root/Announcement") as PanelContainer
@onready var _announcement_title: Label = get_node("Root/Announcement/Content/Title") as Label
@onready var _announcement_subtitle: Label = get_node("Root/Announcement/Content/Subtitle") as Label
@onready var _choice_overlay: Control = get_node("Root/ChoiceOverlay") as Control
@onready var _upgrade_title: Label = get_node("Root/ChoiceOverlay/Center/Card/Content/Title") as Label
@onready var _upgrade_buttons: Array[Button] = [
	get_node("Root/ChoiceOverlay/Center/Card/Content/Choices/Option1") as Button,
	get_node("Root/ChoiceOverlay/Center/Card/Content/Choices/Option2") as Button,
	get_node("Root/ChoiceOverlay/Center/Card/Content/Choices/Option3") as Button,
]
@onready var _result_overlay: Control = get_node("Root/ResultOverlay") as Control
@onready var _result_title: Label = get_node("Root/ResultOverlay/Center/Card/Content/Title") as Label
@onready var _result_subtitle: Label = get_node("Root/ResultOverlay/Center/Card/Content/Subtitle") as Label
@onready var _restart_button: Button = get_node("Root/ResultOverlay/Center/Card/Content/Restart") as Button
@onready var _announcement_timer: Timer = get_node("AnnouncementTimer") as Timer


func _ready() -> void:
	for index: int in _upgrade_buttons.size():
		_upgrade_buttons[index].pressed.connect(_on_upgrade_pressed.bind(index))
	_restart_button.pressed.connect(_on_restart_pressed)
	_announcement_timer.timeout.connect(_on_announcement_timeout)
	call_deferred("_bind_run_director")


func is_upgrade_visible() -> bool:
	return _choice_overlay.visible


func is_result_visible() -> bool:
	return _result_overlay.visible


func _bind_run_director() -> void:
	_run_director = get_tree().get_first_node_in_group(&"run_director") as RunDirector
	if not is_instance_valid(_run_director):
		push_error("SessionUi could not find RunDirector.")
		return
	_run_director.state_changed.connect(_on_state_changed)
	_run_director.upgrade_requested.connect(_on_upgrade_requested)
	_run_director.victory_reached.connect(_on_victory_reached)
	_run_director.defeat_reached.connect(_on_defeat_reached)
	_run_director.run_restarted.connect(_on_run_restarted)
	_sync_to_state(_run_director.current_state)


func _sync_to_state(state: RunDirector.State) -> void:
	_choice_overlay.visible = state == RunDirector.State.UPGRADE
	_result_overlay.visible = state == RunDirector.State.VICTORY or state == RunDirector.State.DEFEAT
	match state:
		RunDirector.State.INTRO:
			_show_announcement("THE WITCHING HOUR", "Survive the omens. Choose your power. Break the conclave.", 0.0)
		RunDirector.State.FINAL:
			_show_announcement("FINAL WAVE", "The Red Conclave has arrived.", 1.4)
		RunDirector.State.COMBAT:
			_announcement.visible = false
		_:
			pass


func _on_state_changed(_previous_state: int, next_state: int) -> void:
	_sync_to_state(next_state)


func _on_upgrade_requested(options: Array[UpgradeData]) -> void:
	_upgrade_options = options
	_choice_overlay.visible = true
	_result_overlay.visible = false
	_announcement.visible = false
	_upgrade_title.text = "CHOOSE ONE RUNE"
	for index: int in _upgrade_buttons.size():
		var button: Button = _upgrade_buttons[index]
		if index >= _upgrade_options.size():
			button.disabled = true
			button.text = "UNAVAILABLE"
			continue
		var upgrade: UpgradeData = _upgrade_options[index]
		button.disabled = false
		button.text = "%s\n%s" % [upgrade.display_name.to_upper(), upgrade.description]
		button.add_theme_color_override("font_color", upgrade.accent_color)
	_upgrade_buttons[0].grab_focus()


func _on_upgrade_pressed(option_index: int) -> void:
	if is_instance_valid(_run_director) and _run_director.choose_upgrade(option_index):
		_choice_overlay.visible = false


func _on_victory_reached() -> void:
	_show_result(
		"VICTORY",
		"The conclave is broken. Your chosen rune endures until the next run."
	)


func _on_defeat_reached() -> void:
	_show_result(
		"DEFEAT",
		"The arena claimed the mage. Begin again with a clean spellbook."
	)


func _show_result(title: String, subtitle: String) -> void:
	_announcement.visible = false
	_choice_overlay.visible = false
	_result_overlay.visible = true
	_result_title.text = title
	_result_subtitle.text = subtitle
	_restart_button.grab_focus()


func _on_restart_pressed() -> void:
	if is_instance_valid(_run_director):
		_run_director.start_new_run()


func _on_run_restarted() -> void:
	_upgrade_options.clear()
	_sync_to_state(RunDirector.State.INTRO)


func _show_announcement(title: String, subtitle: String, duration: float) -> void:
	_announcement_title.text = title
	_announcement_subtitle.text = subtitle
	_announcement.visible = true
	_announcement_timer.stop()
	if duration > 0.0:
		_announcement_timer.start(duration)


func _on_announcement_timeout() -> void:
	_announcement.visible = false
