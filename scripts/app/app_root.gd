class_name AppRoot
extends Node

@export var arena_run_scene: PackedScene

var _current_run: Node
var _settings_from_pause: bool = false

@onready var settings_store: SettingsStore = get_node("SettingsStore") as SettingsStore
@onready var _screen_host: Control = get_node("ScreenHost") as Control
@onready var _main_menu: MainMenu = get_node("ScreenHost/MainMenu") as MainMenu
@onready var _settings_menu: SettingsMenu = get_node("ScreenHost/SettingsMenu") as SettingsMenu
@onready var _run_host: Node = get_node("RunHost")
@onready var _pause_menu: PauseMenu = get_node("PauseMenu") as PauseMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_main_menu.run_requested.connect(start_run)
	_main_menu.settings_requested.connect(_open_settings_from_menu)
	_main_menu.quit_requested.connect(get_tree().quit)
	_settings_menu.bind(settings_store)
	settings_store.settings_changed.connect(_refresh_ui_text)
	_settings_menu.close_requested.connect(_close_settings)
	_pause_menu.resume_requested.connect(_resume_run)
	_pause_menu.settings_requested.connect(_open_settings_from_pause)
	_pause_menu.main_menu_requested.connect(return_to_menu)
	_refresh_ui_text()
	_show_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_current_run) and event.is_action_pressed(&"pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()


func start_run() -> bool:
	if arena_run_scene == null:
		return false
	_clear_run()
	get_tree().paused = false
	_screen_host.visible = false
	_pause_menu.set_open(false)
	_current_run = arena_run_scene.instantiate()
	_run_host.add_child(_current_run)
	var session_ui: SessionUi = _current_run.get_node_or_null("SessionUi") as SessionUi
	if is_instance_valid(session_ui):
		session_ui.main_menu_requested.connect(return_to_menu)
	return true


func return_to_menu() -> void:
	get_tree().paused = false
	_pause_menu.set_open(false)
	_clear_run()
	_show_main_menu()


func toggle_pause() -> void:
	if not is_instance_valid(_current_run):
		return
	var next_paused: bool = not get_tree().paused
	get_tree().paused = next_paused
	_pause_menu.set_open(next_paused)
	_screen_host.visible = false


func get_current_run() -> Node:
	return _current_run


func _open_settings_from_menu() -> void:
	_settings_from_pause = false
	_main_menu.visible = false
	_settings_menu.visible = true


func _open_settings_from_pause() -> void:
	_settings_from_pause = true
	_pause_menu.set_open(false)
	_screen_host.visible = true
	_main_menu.visible = false
	_settings_menu.visible = true


func _close_settings() -> void:
	_settings_menu.visible = false
	if _settings_from_pause and is_instance_valid(_current_run):
		_screen_host.visible = false
		_pause_menu.set_open(true)
	else:
		_show_main_menu()


func _resume_run() -> void:
	get_tree().paused = false
	_pause_menu.set_open(false)


func _show_main_menu() -> void:
	_screen_host.visible = true
	_settings_menu.visible = false
	_main_menu.visible = true


func _refresh_ui_text() -> void:
	_main_menu.refresh_text()
	_settings_menu.refresh_text()
	_pause_menu.refresh_text()


func _clear_run() -> void:
	if is_instance_valid(_current_run):
		if _current_run.get_parent() != null:
			_current_run.get_parent().remove_child(_current_run)
		_current_run.queue_free()
	_current_run = null
