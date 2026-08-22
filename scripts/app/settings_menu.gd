class_name SettingsMenu
extends Control

signal close_requested()

var _store: SettingsStore
var _capture_action: StringName

@onready var _master: HSlider = get_node("Center/Card/Content/Master") as HSlider
@onready var _music: HSlider = get_node("Center/Card/Content/Music") as HSlider
@onready var _sfx: HSlider = get_node("Center/Card/Content/Sfx") as HSlider
@onready var _language: OptionButton = get_node("Center/Card/Content/Language") as OptionButton
@onready var _window_mode: OptionButton = get_node("Center/Card/Content/WindowMode") as OptionButton
@onready var _graphics: OptionButton = get_node("Center/Card/Content/Graphics") as OptionButton
@onready var _cast_button: Button = get_node("Center/Card/Content/RebindCast") as Button
@onready var _dash_button: Button = get_node("Center/Card/Content/RebindDash") as Button
@onready var _status: Label = get_node("Center/Card/Content/Status") as Label
@onready var _save_button: Button = get_node("Center/Card/Content/Save") as Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_language.add_item("Русский", 0)
	_language.add_item("English", 1)
	_window_mode.add_item(tr("WINDOWED"), 0)
	_window_mode.add_item(tr("FULLSCREEN"), 1)
	_graphics.add_item(tr("QUALITY_LOW"), 0)
	_graphics.add_item(tr("QUALITY_HIGH"), 1)
	_cast_button.pressed.connect(_begin_capture.bind(&"primary_spell"))
	_dash_button.pressed.connect(_begin_capture.bind(&"dash"))
	(get_node("Center/Card/Content/Reset") as Button).pressed.connect(_reset_bindings)
	_save_button.pressed.connect(_save_and_close)
	refresh_text()
	visibility_changed.connect(_on_visibility_changed)


func bind(store: SettingsStore) -> void:
	_store = store
	_sync_from_store()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _capture_action == &"":
		return
	if event is not InputEventKey and event is not InputEventMouseButton \
		and event is not InputEventJoypadButton:
		return
	if not event.is_pressed() or event.is_echo():
		return
	if _store.rebind_action(_capture_action, event.duplicate(true) as InputEvent):
		_status.text = "%s: %s" % [_capture_action, event.as_text()]
	_capture_action = &""
	get_viewport().set_input_as_handled()


func _sync_from_store() -> void:
	if not is_instance_valid(_store):
		return
	_master.value = _store.master_volume
	_music.value = _store.music_volume
	_sfx.value = _store.sfx_volume
	_language.selected = 0 if _store.locale == "ru" else 1
	_window_mode.selected = 1 if _store.window_mode == &"fullscreen" else 0
	_graphics.selected = 1 if _store.graphics_quality == &"high" else 0
	_status.text = ""


func _begin_capture(action: StringName) -> void:
	_capture_action = action
	_status.text = tr("SETTINGS_PRESS_INPUT")


func _reset_bindings() -> void:
	_store.reset_input_bindings()
	_status.text = tr("SETTINGS_RESET")


func _save_and_close() -> void:
	_store.set_audio_levels(_master.value, _music.value, _sfx.value)
	_store.set_locale("ru" if _language.selected == 0 else "en")
	_store.set_window_mode(&"fullscreen" if _window_mode.selected == 1 else &"windowed")
	_store.set_graphics_quality(&"high" if _graphics.selected == 1 else &"low")
	_store.save_settings()
	_capture_action = &""
	close_requested.emit()


func _on_visibility_changed() -> void:
	if visible and is_node_ready():
		_sync_from_store()
		_save_button.grab_focus()


func refresh_text() -> void:
	(get_node("Center/Card/Content/Title") as Label).text = tr("SETTINGS_TITLE")
	(get_node("Center/Card/Content/MasterLabel") as Label).text = tr("SETTINGS_MASTER")
	(get_node("Center/Card/Content/MusicLabel") as Label).text = tr("SETTINGS_MUSIC")
	(get_node("Center/Card/Content/SfxLabel") as Label).text = tr("SETTINGS_SFX")
	(get_node("Center/Card/Content/LanguageLabel") as Label).text = tr("SETTINGS_LANGUAGE")
	(get_node("Center/Card/Content/WindowLabel") as Label).text = tr("SETTINGS_WINDOW")
	(get_node("Center/Card/Content/GraphicsLabel") as Label).text = tr("SETTINGS_GRAPHICS")
	_cast_button.text = tr("SETTINGS_REBIND_CAST")
	_dash_button.text = tr("SETTINGS_REBIND_DASH")
	(get_node("Center/Card/Content/Reset") as Button).text = tr("SETTINGS_RESET")
	_save_button.text = tr("SETTINGS_SAVE")
	if _window_mode.item_count == 2:
		_window_mode.set_item_text(0, tr("WINDOWED"))
		_window_mode.set_item_text(1, tr("FULLSCREEN"))
	if _graphics.item_count == 2:
		_graphics.set_item_text(0, tr("QUALITY_LOW"))
		_graphics.set_item_text(1, tr("QUALITY_HIGH"))
