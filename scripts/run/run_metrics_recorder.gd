class_name RunMetricsRecorder
extends Node

@export var metrics_path: String = "user://run_metrics.jsonl"
@export var recording_enabled: bool = true

var _elapsed_seconds: float = 0.0
var _damage_taken: float = 0.0
var _damage_events: Array[Dictionary] = []
var _upgrade_ids: Array[String] = []
var _last_record: Dictionary = {}
var _director: RunDirector
var _waves: WaveDirector


func _ready() -> void:
	call_deferred("_bind_run")


func _process(delta: float) -> void:
	_elapsed_seconds += delta


func get_last_record() -> Dictionary:
	return _last_record.duplicate(true)


func _bind_run() -> void:
	_director = get_tree().get_first_node_in_group(&"run_director") as RunDirector
	_waves = get_tree().get_first_node_in_group(&"wave_director") as WaveDirector
	var player: MagePlayer = get_tree().get_first_node_in_group(&"player") as MagePlayer
	if not is_instance_valid(_director) or not is_instance_valid(player):
		push_error("RunMetricsRecorder requires RunDirector and MagePlayer.")
		return
	_director.run_restarted.connect(_on_run_restarted)
	_director.upgrade_applied.connect(_on_upgrade_applied)
	_director.victory_reached.connect(_record_result.bind(&"victory"))
	_director.defeat_reached.connect(_record_result.bind(&"defeat"))
	player.get_health_component().damaged.connect(_on_player_damaged)
	_on_run_restarted()


func _on_run_restarted() -> void:
	_elapsed_seconds = 0.0
	_damage_taken = 0.0
	_damage_events.clear()
	_upgrade_ids.clear()
	_last_record.clear()


func _on_player_damaged(amount: float) -> void:
	_damage_taken += amount
	var context: String = "unknown"
	if is_instance_valid(_director) and _director.current_state == RunDirector.State.FINAL:
		context = "boss"
	elif is_instance_valid(_waves):
		context = "wave_%d" % _waves.get_current_wave_number()
	_damage_events.append({"amount": snappedf(amount, 0.1), "context": context})


func _on_upgrade_applied(upgrade: UpgradeData) -> void:
	if upgrade != null:
		_upgrade_ids.append(String(upgrade.upgrade_id))


func _record_result(result: StringName) -> void:
	if not recording_enabled:
		return
	_last_record = {
		"version": BuildInfo.VERSION,
		"result": String(result),
		"duration_seconds": snappedf(_elapsed_seconds, 0.01),
		"damage_taken": snappedf(_damage_taken, 0.1),
		"damage_events": _damage_events.duplicate(true),
		"upgrades": _upgrade_ids.duplicate(),
		"utc_timestamp": Time.get_datetime_string_from_system(true),
	}
	var access_mode: FileAccess.ModeFlags = (
		FileAccess.READ_WRITE if FileAccess.file_exists(metrics_path) else FileAccess.WRITE_READ
	)
	var file: FileAccess = FileAccess.open(metrics_path, access_mode)
	if file == null:
		print_verbose("Run metrics could not be stored at %s." % metrics_path)
		return
	file.seek_end()
	file.store_line(JSON.stringify(_last_record))
