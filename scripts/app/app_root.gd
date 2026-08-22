class_name AppRoot
extends Node

@export var arena_run_scene: PackedScene
@export var world_session_scene: PackedScene

var _current_run: Node
var _settings_from_pause: bool = false

@onready var settings_store: SettingsStore = get_node("SettingsStore") as SettingsStore
@onready var save_game_service: SaveGameService = get_node("SaveGameService") as SaveGameService
@onready var _screen_host: Control = get_node("ScreenHost") as Control
@onready var _main_menu: MainMenu = get_node("ScreenHost/MainMenu") as MainMenu
@onready var _settings_menu: SettingsMenu = get_node("ScreenHost/SettingsMenu") as SettingsMenu
@onready var _run_host: Node = get_node("RunHost")
@onready var _pause_menu: PauseMenu = get_node("PauseMenu") as PauseMenu


func _enter_tree() -> void:
	SurvivalInputProfile.ensure_actions()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SurvivalInputProfile.ensure_actions()
	_main_menu.run_requested.connect(start_survival)
	_main_menu.settings_requested.connect(_open_settings_from_menu)
	_main_menu.quit_requested.connect(get_tree().quit)
	_settings_menu.bind(settings_store)
	settings_store.settings_changed.connect(_on_settings_changed)
	_settings_menu.close_requested.connect(_close_settings)
	_pause_menu.resume_requested.connect(_resume_run)
	_pause_menu.settings_requested.connect(_open_settings_from_pause)
	_pause_menu.main_menu_requested.connect(return_to_menu)
	_refresh_ui_text()
	_show_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_current_run) and _current_run is WorldSession \
			and event.is_action_pressed(&"quick_save"):
		save_game_service.save_game(_current_run as WorldSession, 0)
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(_current_run) and event.is_action_pressed(&"pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	SyntheticAudio.release_cached_streams()


func start_run() -> bool:
	if arena_run_scene == null:
		return false
	return _start_session(arena_run_scene)


func start_survival() -> bool:
	if world_session_scene == null:
		return false
	return _start_session(world_session_scene)


func _start_session(session_scene: PackedScene) -> bool:
	_clear_run()
	get_tree().paused = false
	_screen_host.visible = false
	_pause_menu.set_open(false)
	_current_run = session_scene.instantiate()
	_run_host.add_child(_current_run)
	var session_ui: SessionUi = _current_run.get_node_or_null("SessionUi") as SessionUi
	if is_instance_valid(session_ui):
		session_ui.main_menu_requested.connect(return_to_menu)
	if _current_run.has_signal(&"main_menu_requested"):
		_current_run.connect(&"main_menu_requested", return_to_menu)
	if _current_run is WorldSession:
		(_current_run as WorldSession).bind_save_service(save_game_service)
		(_current_run as WorldSession).apply_camera_settings(settings_store)
		(_current_run as WorldSession).set_session_paused(false)
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
	_set_current_run_paused(next_paused)


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
	_set_current_run_paused(false)


func _show_main_menu() -> void:
	_screen_host.visible = true
	_settings_menu.visible = false
	_main_menu.visible = true


func _refresh_ui_text() -> void:
	_main_menu.refresh_text()
	_settings_menu.refresh_text()
	_pause_menu.refresh_text()


func _on_settings_changed() -> void:
	_refresh_ui_text()
	if _current_run is WorldSession:
		var session: WorldSession = _current_run as WorldSession
		session.apply_camera_settings(settings_store)
		session.survival_hud.refresh_input_glyphs()


func _clear_run() -> void:
	if is_instance_valid(_current_run):
		if _current_run.get_parent() != null:
			_current_run.get_parent().remove_child(_current_run)
		_current_run.queue_free()
	_current_run = null


func _set_current_run_paused(paused: bool) -> void:
	if _current_run is WorldSession:
		(_current_run as WorldSession).set_session_paused(paused)
