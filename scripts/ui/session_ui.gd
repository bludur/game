class_name SessionUi
extends CanvasLayer

signal main_menu_requested()

var _run_director: RunDirector
var _upgrade_options: Array[UpgradeData] = []

@onready var _announcement: PanelContainer = get_node("Root/Announcement") as PanelContainer
@onready var _announcement_title: Label = get_node("Root/Announcement/Content/Title") as Label
@onready var _announcement_subtitle: Label = get_node("Root/Announcement/Content/Subtitle") as Label
@onready var _choice_overlay: Control = get_node("Root/ChoiceOverlay") as Control
@onready var _upgrade_title: Label = get_node("Root/ChoiceOverlay/Center/Card/Content/Title") as Label
@onready var _upgrade_hint: Label = get_node("Root/ChoiceOverlay/Center/Card/Content/Hint") as Label
@onready var _upgrade_buttons: Array[Button] = [
	get_node("Root/ChoiceOverlay/Center/Card/Content/Choices/Option1") as Button,
	get_node("Root/ChoiceOverlay/Center/Card/Content/Choices/Option2") as Button,
	get_node("Root/ChoiceOverlay/Center/Card/Content/Choices/Option3") as Button,
]
@onready var _result_overlay: Control = get_node("Root/ResultOverlay") as Control
@onready var _result_title: Label = get_node("Root/ResultOverlay/Center/Card/Content/Title") as Label
@onready var _result_subtitle: Label = get_node("Root/ResultOverlay/Center/Card/Content/Subtitle") as Label
@onready var _restart_button: Button = get_node("Root/ResultOverlay/Center/Card/Content/Restart") as Button
@onready var _main_menu_button: Button = get_node("Root/ResultOverlay/Center/Card/Content/MainMenu") as Button
@onready var _version_label: Label = get_node("Root/Version") as Label
@onready var _announcement_timer: Timer = get_node("AnnouncementTimer") as Timer


func _ready() -> void:
	UiTranslations.ensure_registered()
	_version_label.text = "v%s" % BuildInfo.VERSION
	_upgrade_hint.text = tr("RUN_UPGRADE_HINT")
	_restart_button.text = tr("RUN_RESTART")
	_main_menu_button.text = tr("RESULT_MENU")
	for index: int in _upgrade_buttons.size():
		_upgrade_buttons[index].pressed.connect(_on_upgrade_pressed.bind(index))
	_restart_button.pressed.connect(_on_restart_pressed)
	_main_menu_button.pressed.connect(main_menu_requested.emit)
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
			_show_announcement(tr("RUN_INTRO_TITLE"), tr("RUN_INTRO_SUBTITLE"), 0.0)
		RunDirector.State.FINAL:
			_show_announcement(tr("RUN_FINAL_TITLE"), tr("RUN_FINAL_SUBTITLE"), 1.4)
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
	_upgrade_title.text = tr("RUN_UPGRADE_TITLE")
	for index: int in _upgrade_buttons.size():
		var button: Button = _upgrade_buttons[index]
		if index >= _upgrade_options.size():
			button.disabled = true
			button.text = tr("RUN_UNAVAILABLE")
			continue
		var upgrade: UpgradeData = _upgrade_options[index]
		button.disabled = false
		var key_stem: String = "UPGRADE_%s" % String(upgrade.upgrade_id).to_upper()
		button.text = "%s\n%s" % [tr(key_stem + "_NAME"), tr(key_stem + "_DESC")]
		button.add_theme_color_override("font_color", upgrade.accent_color)
	_upgrade_buttons[0].grab_focus()


func _on_upgrade_pressed(option_index: int) -> void:
	if is_instance_valid(_run_director) and _run_director.choose_upgrade(option_index):
		_choice_overlay.visible = false


func _on_victory_reached() -> void:
	_show_result(
		tr("RUN_VICTORY"),
		tr("RUN_VICTORY_TEXT")
	)


func _on_defeat_reached() -> void:
	_show_result(
		tr("RUN_DEFEAT"),
		tr("RUN_DEFEAT_TEXT")
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
