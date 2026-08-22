class_name DashComponent
extends Node

signal dash_requested()
signal dash_started(direction: Vector3)
signal dash_finished()
signal cooldown_changed(remaining: float, total: float)

@export_range(4.0, 30.0, 0.5) var dash_speed: float = 13.0
@export_range(0.05, 1.0, 0.01) var dash_duration: float = 0.25
@export_range(0.1, 10.0, 0.1) var cooldown_duration: float = 1.6

var is_dashing: bool = false
var dash_direction: Vector3 = Vector3.FORWARD
var _enabled: bool = true

@onready var _duration_timer: Timer = get_node("DurationTimer") as Timer
@onready var _cooldown_timer: Timer = get_node("CooldownTimer") as Timer


func _ready() -> void:
	_duration_timer.timeout.connect(_on_duration_finished)
	_cooldown_timer.timeout.connect(_on_cooldown_finished)
	set_process(false)


func _unhandled_input(event: InputEvent) -> void:
	if _enabled and event.is_action_pressed(&"dash"):
		dash_requested.emit()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	cooldown_changed.emit(_cooldown_timer.time_left, cooldown_duration)


func try_begin(direction: Vector3) -> bool:
	if not can_begin(direction):
		return false
	direction.y = 0.0
	dash_direction = direction.normalized()
	is_dashing = true
	_duration_timer.start(dash_duration)
	_cooldown_timer.start(cooldown_duration)
	set_process(true)
	dash_started.emit(dash_direction)
	cooldown_changed.emit(cooldown_duration, cooldown_duration)
	return true


func can_begin(direction: Vector3) -> bool:
	if not _enabled or is_dashing or not _cooldown_timer.is_stopped():
		return false
	direction.y = 0.0
	return direction.length_squared() > 0.001


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	set_process_unhandled_input(enabled)
	if enabled:
		return
	if is_dashing:
		is_dashing = false
		dash_finished.emit()
	_duration_timer.stop()
	_cooldown_timer.stop()
	set_process(false)
	cooldown_changed.emit(0.0, cooldown_duration)


func get_cooldown_remaining() -> float:
	return _cooldown_timer.time_left


func _on_duration_finished() -> void:
	if not is_dashing:
		return
	is_dashing = false
	dash_finished.emit()


func _on_cooldown_finished() -> void:
	set_process(false)
	cooldown_changed.emit(0.0, cooldown_duration)
