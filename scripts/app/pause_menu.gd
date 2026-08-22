class_name PauseMenu
extends CanvasLayer

signal resume_requested()
signal settings_requested()
signal main_menu_requested()

@onready var _panel: Control = get_node("Root") as Control
@onready var _resume_button: Button = get_node("Root/Center/Card/Content/Resume") as Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_resume_button.pressed.connect(resume_requested.emit)
	(get_node("Root/Center/Card/Content/Settings") as Button).pressed.connect(settings_requested.emit)
	(get_node("Root/Center/Card/Content/MainMenu") as Button).pressed.connect(main_menu_requested.emit)
	refresh_text()
	set_open(false)


func refresh_text() -> void:
	(get_node("Root/Center/Card/Content/Title") as Label).text = tr("PAUSED")
	_resume_button.text = tr("MENU_RESUME")
	(get_node("Root/Center/Card/Content/Settings") as Button).text = tr("MENU_SETTINGS")
	(get_node("Root/Center/Card/Content/MainMenu") as Button).text = tr("MENU_MAIN")


func set_open(is_open: bool) -> void:
	_panel.visible = is_open
	if is_open and is_node_ready():
		_resume_button.grab_focus()


func is_open() -> bool:
	return _panel.visible
