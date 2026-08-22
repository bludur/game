class_name SaveGameService
extends Node

signal save_completed(slot_index: int)
signal load_completed(slot_index: int)
signal save_failed(slot_index: int, reason: String)

const CURRENT_VERSION: int = 1
const SLOT_COUNT: int = 2

@export var save_directory: String = "user://saves/witchroot/"


func save_game(session: WorldSession, slot_index: int = 0) -> bool:
	if not _is_valid_slot(slot_index) or not is_instance_valid(session):
		return false
	if not _ensure_save_directory():
		save_failed.emit(slot_index, "directory_failed")
		return false
	var snapshot: Dictionary = session.serialize_game()
	snapshot["version"] = CURRENT_VERSION
	snapshot["timestamp"] = Time.get_unix_time_from_system()
	var path: String = _slot_path(slot_index)
	var temporary_path: String = path + ".tmp"
	var backup_path: String = path + ".bak"
	if not _write_json(temporary_path, snapshot):
		save_failed.emit(slot_index, "write_failed")
		return false
	if _read_json(temporary_path).is_empty():
		save_failed.emit(slot_index, "verification_failed")
		return false
	var absolute_path: String = ProjectSettings.globalize_path(path)
	var absolute_temporary: String = ProjectSettings.globalize_path(temporary_path)
	var absolute_backup: String = ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup)
	if FileAccess.file_exists(path):
		var backup_error: Error = DirAccess.rename_absolute(absolute_path, absolute_backup)
		if backup_error != OK:
			save_failed.emit(slot_index, "backup_failed")
			return false
	var replace_error: Error = DirAccess.rename_absolute(absolute_temporary, absolute_path)
	if replace_error != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup, absolute_path)
		save_failed.emit(slot_index, "replace_failed")
		return false
	save_completed.emit(slot_index)
	return true


func load_game(session: WorldSession, slot_index: int = 0) -> bool:
	if not _is_valid_slot(slot_index) or not is_instance_valid(session):
		return false
	var path: String = _slot_path(slot_index)
	var snapshot: Dictionary = _read_json(path)
	if snapshot.is_empty():
		snapshot = _read_json(path + ".bak")
	if snapshot.is_empty():
		return false
	snapshot = _migrate(snapshot)
	if not session.apply_game(snapshot):
		return false
	load_completed.emit(slot_index)
	return true


func has_save(slot_index: int = 0) -> bool:
	return _is_valid_slot(slot_index) and (FileAccess.file_exists(_slot_path(slot_index)) \
		or FileAccess.file_exists(_slot_path(slot_index) + ".bak"))


func get_save_slots() -> Array[int]:
	var slots: Array[int] = []
	for slot_index: int in SLOT_COUNT:
		if has_save(slot_index):
			slots.append(slot_index)
	return slots


func delete_save(slot_index: int) -> bool:
	if not _is_valid_slot(slot_index):
		return false
	var removed_any: bool = false
	for suffix: String in ["", ".bak", ".tmp"]:
		var path: String = _slot_path(slot_index) + suffix
		if FileAccess.file_exists(path):
			removed_any = DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK or removed_any
	return removed_any


func read_snapshot(slot_index: int) -> Dictionary:
	if not _is_valid_slot(slot_index):
		return {}
	var snapshot: Dictionary = _read_json(_slot_path(slot_index))
	if snapshot.is_empty():
		snapshot = _read_json(_slot_path(slot_index) + ".bak")
	return _migrate(snapshot) if not snapshot.is_empty() else {}


func _write_json(path: String, data: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveGameService: cannot open '%s', error %d." % [path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	return true


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK or json.data is not Dictionary:
		return {}
	return (json.data as Dictionary).duplicate(true)


func _migrate(snapshot: Dictionary) -> Dictionary:
	var version: int = int(snapshot.get("version", 0))
	if version < 1:
		if not snapshot.has("world_state"):
			snapshot["world_state"] = {}
		version = 1
	snapshot["version"] = version
	return snapshot


func _slot_path(slot_index: int) -> String:
	return "%sslot_%d.json" % [save_directory, slot_index]


func _is_valid_slot(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < SLOT_COUNT


func _ensure_save_directory() -> bool:
	var error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_directory))
	if error == OK or error == ERR_ALREADY_EXISTS:
		return true
	push_error("SaveGameService: could not create save directory, error %d." % error)
	return false
