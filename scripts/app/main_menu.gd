class_name MainMenu
extends Control

signal run_requested()
signal settings_requested()
signal quit_requested()

@onready var _start_button: Button = get_node("Center/Card/Content/Start") as Button
@onready var _settings_button: Button = get_node("Center/Card/Content/Settings") as Button
@onready var _quit_button: Button = get_node("Center/Card/Content/Quit") as Button


func _ready() -> void:
	_start_button.pressed.connect(run_requested.emit)
	_settings_button.pressed.connect(settings_requested.emit)
	_quit_button.pressed.connect(quit_requested.emit)
	visibility_changed.connect(_on_visibility_changed)
	refresh_text()
	_on_visibility_changed()


func refresh_text() -> void:
	(get_node("Center/Card/Content/Title") as Label).text = tr("GAME_TITLE")
	(get_node("Center/Card/Content/Subtitle") as Label).text = "%s  •  v%s" % [
		tr("GAME_SUBTITLE"), BuildInfo.VERSION
	]
	_start_button.text = tr("MENU_START")
	_settings_button.text = tr("MENU_SETTINGS")
	_quit_button.text = tr("MENU_QUIT")


func _on_visibility_changed() -> void:
	if visible and is_node_ready():
		_start_button.grab_focus()
